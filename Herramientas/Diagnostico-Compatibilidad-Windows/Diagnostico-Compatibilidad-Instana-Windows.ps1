#requires -version 3.0
<#
.SYNOPSIS
    Valida compatibilidad tecnologica de un servidor Windows e IIS con IBM Instana.

.DESCRIPTION
    Compatible para su ejecucion desde Windows Server 2012 y Windows PowerShell 3.0.

    El objetivo del script es exclusivamente determinar si las tecnologias detectadas
    se encuentran soportadas por IBM Instana y reunir la evidencia tecnica utilizada.

    Evalua:
      - Sistema operativo Windows y arquitectura.
      - Microsoft IIS y Application Pools.
      - Aplicaciones .NET Framework y .NET / .NET Core desplegadas en IIS.
      - Versiones de .NET instaladas.
      - Microsoft SQL Server local, cuando existe.
      - Requisitos de capacidad informativos para monitoreo .NET.

    NO valida:
      - Instalacion o estado del agente Instana.
      - Instrumentacion, profiler, sensores o generacion de trazas.
      - Conectividad con el backend de Instana.
      - Credenciales o configuracion del agente.

    El script es de solo lectura. No reinicia servicios, no modifica IIS y no copia
    archivos web.config completos, connection strings, contrasenas o certificados.

.NOTES
    Matriz de soporte incorporada: 2026-07-29.
    La evaluacion diferencia soporte GA, soporte deprecado, limitaciones documentadas
    y casos donde la evidencia no permite una conclusion automatica.
    Verificar periodicamente contra la documentacion oficial de IBM Instana.
#>

param(
    [switch]$MantenerVentanaAbierta
)

$ErrorActionPreference = 'Stop'

trap {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkGray
    Write-Host 'EL DIAGNOSTICO NO PUDO COMPLETARSE' -ForegroundColor Red
    Write-Host '============================================================' -ForegroundColor DarkGray
    Write-Host ('Detalle: {0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'No se realizaron cambios en el servidor.' -ForegroundColor Yellow

    if ($MantenerVentanaAbierta) {
        Write-Host ''
        [void](Read-Host 'Presione ENTER para cerrar esta ventana')
    }

    exit 1
}


# -----------------------------------------------------------------------------
# Criterios de soporte incorporados
# -----------------------------------------------------------------------------

$SupportMatrixDate = '2026-07-29'

$SupportedWindowsServerNames = @(
    'Windows Server 2012 R2',
    'Windows Server 2012',
    'Windows Server 2016',
    'Windows Server 2019',
    'Windows Server 2022',
    'Windows Server 2025'
)

$SupportedSqlYears = @(2016, 2017, 2019, 2022, 2025)
$MinimumDotNetFramework = New-Object System.Version -ArgumentList 4,5,2
$MinimumModernDotNetMajor = 5

# -----------------------------------------------------------------------------
# Funciones generales
# -----------------------------------------------------------------------------

function Add-DiagnosticError {
    param(
        [string]$Seccion,
        [string]$Mensaje
    )

    $registro = New-Object PSObject -Property @{
        Fecha   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Seccion = $Seccion
        Mensaje = $Mensaje
    }

    [void]$script:Errores.Add($registro)
}

function Export-CsvSafe {
    param(
        [object[]]$Datos,
        [string]$Ruta,
        [string]$MensajeVacio
    )

    if ($null -ne $Datos -and @($Datos).Count -gt 0) {
        $Datos | Export-Csv -LiteralPath $Ruta -NoTypeInformation -Encoding UTF8
    }
    else {
        (New-Object PSObject -Property @{ Estado = $MensajeVacio }) |
            Export-Csv -LiteralPath $Ruta -NoTypeInformation -Encoding UTF8
    }
}

function Test-DirectoryWritable {
    param([string]$Ruta)

    try {
        if (-not (Test-Path -LiteralPath $Ruta -PathType Container)) {
            return $false
        }

        $archivoPrueba = Join-Path $Ruta ('.__instana_compat_{0}.tmp' -f ([Guid]::NewGuid().ToString('N')))
        [System.IO.File]::WriteAllText($archivoPrueba, 'test')
        Remove-Item -LiteralPath $archivoPrueba -Force
        return $true
    }
    catch {
        return $false
    }
}

function New-ZipFile {
    param(
        [string]$CarpetaOrigen,
        [string]$ArchivoZip
    )

    if (Test-Path -LiteralPath $ArchivoZip) {
        Remove-Item -LiteralPath $ArchivoZip -Force
    }

    $compressArchive = Get-Command Compress-Archive -ErrorAction SilentlyContinue
    if ($null -ne $compressArchive) {
        Compress-Archive -Path (Join-Path $CarpetaOrigen '*') -DestinationPath $ArchivoZip -Force
        return
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $CarpetaOrigen,
        $ArchivoZip,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )
}

function Get-XmlAttributeValue {
    param(
        [System.Xml.XmlNode]$Nodo,
        [string]$Nombre
    )

    if ($null -eq $Nodo -or $null -eq $Nodo.Attributes) {
        return $null
    }

    $atributo = $Nodo.Attributes[$Nombre]
    if ($null -ne $atributo) {
        return [string]$atributo.Value
    }

    return $null
}

function Get-ObjectPropertyValue {
    param(
        [object]$Objeto,
        [string]$Nombre,
        [object]$ValorPredeterminado = $null
    )

    if ($null -eq $Objeto) {
        return $ValorPredeterminado
    }

    $propiedad = $Objeto.PSObject.Properties[$Nombre]
    if ($null -ne $propiedad) {
        return $propiedad.Value
    }

    return $ValorPredeterminado
}

function Convert-ToVersionSafe {
    param([string]$Texto)

    if ([string]::IsNullOrWhiteSpace($Texto)) {
        return $null
    }

    $match = [regex]::Match($Texto, '(?i)(\d+)\.(\d+)(?:\.(\d+))?(?:\.(\d+))?')
    if (-not $match.Success) {
        return $null
    }

    $major = [int]$match.Groups[1].Value
    $minor = [int]$match.Groups[2].Value
    $build = 0
    $revision = 0

    if ($match.Groups[3].Success) { $build = [int]$match.Groups[3].Value }
    if ($match.Groups[4].Success) { $revision = [int]$match.Groups[4].Value }

    return New-Object System.Version -ArgumentList $major,$minor,$build,$revision
}

function Get-DotNetFramework45PlusVersion {
    param([int]$Release)

    if ($Release -ge 533320) { return '4.8.1 o posterior' }
    if ($Release -ge 528040) { return '4.8' }
    if ($Release -ge 461808) { return '4.7.2' }
    if ($Release -ge 461308) { return '4.7.1' }
    if ($Release -ge 460798) { return '4.7' }
    if ($Release -ge 394802) { return '4.6.2' }
    if ($Release -ge 394254) { return '4.6.1' }
    if ($Release -ge 393295) { return '4.6' }
    if ($Release -ge 379893) { return '4.5.2' }
    if ($Release -ge 378675) { return '4.5.1' }
    if ($Release -ge 378389) { return '4.5' }
    return 'No identificada'
}

function Get-WindowsServerFamily {
    param([string]$Caption)

    foreach ($supportedName in $SupportedWindowsServerNames) {
        if ($Caption -like ('*' + $supportedName + '*')) {
            return $supportedName
        }
    }

    return ''
}

function Get-TargetFrameworkClassification {
    param([string]$Valor)

    $resultado = New-Object PSObject -Property @{
        ValorOriginal = $Valor
        Familia       = 'No identificada'
        Version       = ''
        Estado        = 'NO DETERMINADO'
        Sustento      = 'No fue posible interpretar el valor.'
    }

    if ([string]::IsNullOrWhiteSpace($Valor)) {
        return $resultado
    }

    $texto = $Valor.Trim()
    $textoLower = $texto.ToLowerInvariant()

    # TFM compactos de .NET Framework: net452, net472, net48, net481.
    $tfmFramework = [regex]::Match($textoLower, '^net(4)(\d)(\d?)$')
    if ($tfmFramework.Success) {
        $minor = [int]$tfmFramework.Groups[2].Value
        $patch = 0
        if ($tfmFramework.Groups[3].Success -and $tfmFramework.Groups[3].Value.Length -gt 0) {
            $patch = [int]$tfmFramework.Groups[3].Value
        }

        $version = New-Object System.Version -ArgumentList 4,$minor,$patch
        $resultado.Familia = '.NET Framework'
        $resultado.Version = $version.ToString()
        if ($version -ge $MinimumDotNetFramework) {
            $resultado.Estado = 'SOPORTADO'
            $resultado.Sustento = '.NET Framework 4.5.2 o posterior: soporte GA.'
        }
        else {
            $resultado.Estado = 'TARGET ANTERIOR AL MINIMO'
            $resultado.Sustento = 'La aplicacion declara un target anterior a .NET Framework 4.5.2; debe evaluarse junto con el runtime efectivo instalado.'
        }
        return $resultado
    }

    # .NET Framework en formato descriptivo o de web.config.
    if ($textoLower -match 'netframework|\.net framework|version=v[234]\.|^v[234]\.|^[234]\.\d') {
        $version = Convert-ToVersionSafe -Texto $texto
        if ($null -ne $version) {
            $resultado.Familia = '.NET Framework'
            $resultado.Version = ('{0}.{1}.{2}' -f $version.Major, $version.Minor, $version.Build).TrimEnd('.0')
            if ($version -ge $MinimumDotNetFramework) {
                $resultado.Estado = 'SOPORTADO'
                $resultado.Sustento = '.NET Framework 4.5.2 o posterior: soporte GA.'
            }
            else {
                $resultado.Estado = 'TARGET ANTERIOR AL MINIMO'
                $resultado.Sustento = 'La aplicacion declara un target anterior a .NET Framework 4.5.2; debe evaluarse junto con el runtime efectivo instalado.'
            }
            return $resultado
        }
    }

    # TFM modernos: net5.0, net6.0, net7.0, net8.0, net9.0, etc.
    $tfmModern = [regex]::Match($textoLower, '^net(\d+)\.(\d+)')
    if ($tfmModern.Success) {
        $major = [int]$tfmModern.Groups[1].Value
        $minor = [int]$tfmModern.Groups[2].Value
        $resultado.Familia = '.NET'
        $resultado.Version = ('{0}.{1}' -f $major, $minor)

        if ($major -ge $MinimumModernDotNetMajor) {
            if ($major -eq 9) {
                $resultado.Estado = 'SOPORTADO CON LIMITACION'
                $resultado.Sustento = '.NET 9 admite instrumentacion; el profiling no esta soportado actualmente.'
            }
            else {
                $resultado.Estado = 'SOPORTADO'
                $resultado.Sustento = '.NET 5.0 o posterior: soporte GA.'
            }
        }
        elseif ($major -eq 2 -or $major -eq 3) {
            $resultado.Estado = 'DEPRECADO'
            $resultado.Sustento = '.NET Core 2.x y 3.x figuran con soporte deprecado; se recomienda modernizacion planificada.'
        }
        else {
            $resultado.Estado = 'NO SOPORTADO'
            $resultado.Sustento = 'La version detectada no se encuentra incluida en el rango actual de soporte de runtime.'
        }
        return $resultado
    }

    # .NET Core / .NET en runtimeconfig.json.
    if ($textoLower -match 'netcoreapp|microsoft\.netcore\.app|microsoft\.aspnetcore\.app|\.netcoreapp|\.net,version|\.net core') {
        $version = Convert-ToVersionSafe -Texto $texto
        if ($null -ne $version) {
            $resultado.Familia = '.NET'
            $resultado.Version = ('{0}.{1}' -f $version.Major, $version.Minor)

            if ($version.Major -ge $MinimumModernDotNetMajor) {
                if ($version.Major -eq 9) {
                    $resultado.Estado = 'SOPORTADO CON LIMITACION'
                    $resultado.Sustento = '.NET 9 admite instrumentacion; el profiling no esta soportado actualmente.'
                }
                else {
                    $resultado.Estado = 'SOPORTADO'
                    $resultado.Sustento = '.NET 5.0 o posterior: soporte GA.'
                }
            }
            elseif ($version.Major -eq 2 -or $version.Major -eq 3) {
                $resultado.Estado = 'DEPRECADO'
                $resultado.Sustento = '.NET Core 2.x y 3.x figuran con soporte deprecado; se recomienda modernizacion planificada.'
            }
            else {
                $resultado.Estado = 'NO SOPORTADO'
                $resultado.Sustento = 'La version detectada no se encuentra incluida en el rango actual de soporte de runtime.'
            }
            return $resultado
        }
    }

    return $resultado
}

function Get-ApplicationFrameworkEvidence {
    param(
        [string]$Aplicacion,
        [string]$RutaFisica
    )

    $resultados = New-Object System.Collections.ArrayList

    if ([string]::IsNullOrWhiteSpace($RutaFisica)) {
        [void]$resultados.Add((New-Object PSObject -Property @{
            Aplicacion = $Aplicacion
            Fuente     = 'Ruta IIS'
            Archivo    = ''
            Indicador  = ''
            Valor      = ''
            Estado     = 'Ruta fisica no disponible'
        }))
        return @($resultados)
    }

    $rutaExpandida = [Environment]::ExpandEnvironmentVariables($RutaFisica)
    if (-not (Test-Path -LiteralPath $rutaExpandida -PathType Container)) {
        [void]$resultados.Add((New-Object PSObject -Property @{
            Aplicacion = $Aplicacion
            Fuente     = 'Ruta IIS'
            Archivo    = $rutaExpandida
            Indicador  = ''
            Valor      = ''
            Estado     = 'Ruta no accesible o no existente'
        }))
        return @($resultados)
    }

    $webConfig = Join-Path $rutaExpandida 'web.config'
    if (Test-Path -LiteralPath $webConfig -PathType Leaf) {
        try {
            $xml = New-Object System.Xml.XmlDocument
            $xml.PreserveWhitespace = $false
            $xml.XmlResolver = $null
            $xml.Load($webConfig)

            $httpRuntimeNode = $xml.SelectSingleNode('/configuration/system.web/httpRuntime')
            $compilationNode = $xml.SelectSingleNode('/configuration/system.web/compilation')
            $aspNetCoreNode = $xml.SelectSingleNode('/configuration/system.webServer/aspNetCore')
            $supportedRuntimeNodes = @($xml.SelectNodes('/configuration/startup/supportedRuntime'))

            $httpRuntime = Get-XmlAttributeValue -Nodo $httpRuntimeNode -Nombre 'targetFramework'
            if (-not [string]::IsNullOrWhiteSpace($httpRuntime)) {
                [void]$resultados.Add((New-Object PSObject -Property @{
                    Aplicacion = $Aplicacion
                    Fuente     = 'web.config'
                    Archivo    = $webConfig
                    Indicador  = 'httpRuntime targetFramework'
                    Valor      = $httpRuntime
                    Estado     = 'Leido sin copiar el archivo'
                }))
            }

            $compilation = Get-XmlAttributeValue -Nodo $compilationNode -Nombre 'targetFramework'
            if (-not [string]::IsNullOrWhiteSpace($compilation)) {
                [void]$resultados.Add((New-Object PSObject -Property @{
                    Aplicacion = $Aplicacion
                    Fuente     = 'web.config'
                    Archivo    = $webConfig
                    Indicador  = 'compilation targetFramework'
                    Valor      = $compilation
                    Estado     = 'Leido sin copiar el archivo'
                }))
            }

            foreach ($runtimeNode in $supportedRuntimeNodes) {
                $runtimeVersion = Get-XmlAttributeValue -Nodo $runtimeNode -Nombre 'version'
                $runtimeSku = Get-XmlAttributeValue -Nodo $runtimeNode -Nombre 'sku'

                if (-not [string]::IsNullOrWhiteSpace($runtimeVersion)) {
                    [void]$resultados.Add((New-Object PSObject -Property @{
                        Aplicacion = $Aplicacion
                        Fuente     = 'web.config'
                        Archivo    = $webConfig
                        Indicador  = 'supportedRuntime version'
                        Valor      = $runtimeVersion
                        Estado     = 'Leido sin copiar el archivo'
                    }))
                }

                if (-not [string]::IsNullOrWhiteSpace($runtimeSku)) {
                    [void]$resultados.Add((New-Object PSObject -Property @{
                        Aplicacion = $Aplicacion
                        Fuente     = 'web.config'
                        Archivo    = $webConfig
                        Indicador  = 'supportedRuntime sku'
                        Valor      = $runtimeSku
                        Estado     = 'Leido sin copiar el archivo'
                    }))
                }
            }

            if ($null -ne $aspNetCoreNode) {
                foreach ($attributeName in @('hostingModel', 'processPath')) {
                    $attributeValue = Get-XmlAttributeValue -Nodo $aspNetCoreNode -Nombre $attributeName
                    if (-not [string]::IsNullOrWhiteSpace($attributeValue)) {
                        [void]$resultados.Add((New-Object PSObject -Property @{
                            Aplicacion = $Aplicacion
                            Fuente     = 'web.config'
                            Archivo    = $webConfig
                            Indicador  = ('aspNetCore ' + $attributeName)
                            Valor      = $attributeValue
                            Estado     = 'Leido sin copiar el archivo'
                        }))
                    }
                }
            }
        }
        catch {
            [void]$resultados.Add((New-Object PSObject -Property @{
                Aplicacion = $Aplicacion
                Fuente     = 'web.config'
                Archivo    = $webConfig
                Indicador  = ''
                Valor      = ''
                Estado     = ('No se pudo interpretar: ' + $_.Exception.Message)
            }))
        }
    }

    try {
        $runtimeConfigFiles = @(
            Get-ChildItem -LiteralPath $rutaExpandida -Filter '*.runtimeconfig.json' -ErrorAction SilentlyContinue |
                Where-Object { -not $_.PSIsContainer }
        )

        foreach ($runtimeConfigFile in $runtimeConfigFiles) {
            try {
                $jsonText = [System.IO.File]::ReadAllText($runtimeConfigFile.FullName)
                $json = $jsonText | ConvertFrom-Json
                $runtimeOptions = Get-ObjectPropertyValue -Objeto $json -Nombre 'runtimeOptions'

                $tfm = [string](Get-ObjectPropertyValue -Objeto $runtimeOptions -Nombre 'tfm' -ValorPredeterminado '')
                if (-not [string]::IsNullOrWhiteSpace($tfm)) {
                    [void]$resultados.Add((New-Object PSObject -Property @{
                        Aplicacion = $Aplicacion
                        Fuente     = 'runtimeconfig.json'
                        Archivo    = $runtimeConfigFile.FullName
                        Indicador  = 'tfm'
                        Valor      = $tfm
                        Estado     = 'Leido sin copiar el archivo'
                    }))
                }

                $framework = Get-ObjectPropertyValue -Objeto $runtimeOptions -Nombre 'framework'
                if ($null -ne $framework) {
                    $frameworkName = [string](Get-ObjectPropertyValue -Objeto $framework -Nombre 'name' -ValorPredeterminado '')
                    $frameworkVersion = [string](Get-ObjectPropertyValue -Objeto $framework -Nombre 'version' -ValorPredeterminado '')
                    $combined = ($frameworkName + ' ' + $frameworkVersion).Trim()
                    if (-not [string]::IsNullOrWhiteSpace($combined)) {
                        [void]$resultados.Add((New-Object PSObject -Property @{
                            Aplicacion = $Aplicacion
                            Fuente     = 'runtimeconfig.json'
                            Archivo    = $runtimeConfigFile.FullName
                            Indicador  = 'framework'
                            Valor      = $combined
                            Estado     = 'Leido sin copiar el archivo'
                        }))
                    }
                }

                foreach ($propertyName in @('frameworks', 'includedFrameworks')) {
                    $frameworkCollection = Get-ObjectPropertyValue -Objeto $runtimeOptions -Nombre $propertyName
                    foreach ($frameworkItem in @($frameworkCollection)) {
                        if ($null -eq $frameworkItem) { continue }
                        $frameworkName = [string](Get-ObjectPropertyValue -Objeto $frameworkItem -Nombre 'name' -ValorPredeterminado '')
                        $frameworkVersion = [string](Get-ObjectPropertyValue -Objeto $frameworkItem -Nombre 'version' -ValorPredeterminado '')
                        $combined = ($frameworkName + ' ' + $frameworkVersion).Trim()
                        if (-not [string]::IsNullOrWhiteSpace($combined)) {
                            [void]$resultados.Add((New-Object PSObject -Property @{
                                Aplicacion = $Aplicacion
                                Fuente     = 'runtimeconfig.json'
                                Archivo    = $runtimeConfigFile.FullName
                                Indicador  = $propertyName
                                Valor      = $combined
                                Estado     = 'Leido sin copiar el archivo'
                            }))
                        }
                    }
                }
            }
            catch {
                [void]$resultados.Add((New-Object PSObject -Property @{
                    Aplicacion = $Aplicacion
                    Fuente     = 'runtimeconfig.json'
                    Archivo    = $runtimeConfigFile.FullName
                    Indicador  = ''
                    Valor      = ''
                    Estado     = ('No se pudo interpretar: ' + $_.Exception.Message)
                }))
            }
        }
    }
    catch {
        [void]$resultados.Add((New-Object PSObject -Property @{
            Aplicacion = $Aplicacion
            Fuente     = 'runtimeconfig.json'
            Archivo    = $rutaExpandida
            Indicador  = ''
            Valor      = ''
            Estado     = ('No se pudo buscar runtimeconfig.json: ' + $_.Exception.Message)
        }))
    }

    # Evidencia adicional desde TargetFrameworkAttribute. ReflectionOnlyLoadFrom no ejecuta codigo.
    try {
        $assemblyCandidates = New-Object System.Collections.ArrayList
        $binPath = Join-Path $rutaExpandida 'bin'

        if (Test-Path -LiteralPath $binPath -PathType Container) {
            foreach ($file in @(Get-ChildItem -LiteralPath $binPath -Filter '*.dll' -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -First 40)) {
                [void]$assemblyCandidates.Add($file)
            }
        }

        foreach ($file in @(Get-ChildItem -LiteralPath $rutaExpandida -Filter '*.exe' -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -First 10)) {
            [void]$assemblyCandidates.Add($file)
        }

        foreach ($file in @($assemblyCandidates)) {
            try {
                $assembly = [System.Reflection.Assembly]::ReflectionOnlyLoadFrom($file.FullName)
                $attributes = [System.Reflection.CustomAttributeData]::GetCustomAttributes($assembly)
                foreach ($attribute in $attributes) {
                    if ($attribute.AttributeType.FullName -eq 'System.Runtime.Versioning.TargetFrameworkAttribute' -and $attribute.ConstructorArguments.Count -gt 0) {
                        $targetFramework = [string]$attribute.ConstructorArguments[0].Value
                        if (-not [string]::IsNullOrWhiteSpace($targetFramework)) {
                            [void]$resultados.Add((New-Object PSObject -Property @{
                                Aplicacion = $Aplicacion
                                Fuente     = 'Assembly TargetFrameworkAttribute'
                                Archivo    = $file.FullName
                                Indicador  = 'TargetFrameworkAttribute'
                                Valor      = $targetFramework
                                Estado     = 'Metadato leido sin ejecutar el ensamblado'
                            }))
                        }
                    }
                }
            }
            catch {
                # Muchos ensamblados de terceros no pueden abrirse en ReflectionOnlyLoadFrom.
                # No se registra como error general porque runtimeconfig/web.config son las fuentes principales.
            }
        }
    }
    catch {
        [void]$resultados.Add((New-Object PSObject -Property @{
            Aplicacion = $Aplicacion
            Fuente     = 'Assembly TargetFrameworkAttribute'
            Archivo    = $rutaExpandida
            Indicador  = ''
            Valor      = ''
            Estado     = ('No se pudo revisar metadatos de ensamblados: ' + $_.Exception.Message)
        }))
    }

    if (@($resultados).Count -eq 0) {
        [void]$resultados.Add((New-Object PSObject -Property @{
            Aplicacion = $Aplicacion
            Fuente     = 'Aplicacion'
            Archivo    = $rutaExpandida
            Indicador  = ''
            Valor      = ''
            Estado     = 'No se encontraron indicadores de version'
        }))
    }

    return @($resultados)
}

# -----------------------------------------------------------------------------
# Preparacion de salida
# -----------------------------------------------------------------------------

$Errores = New-Object System.Collections.ArrayList

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$esAdministrador = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$baseOutput = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($baseOutput) -or -not (Test-DirectoryWritable -Ruta $baseOutput)) {
    $baseOutput = $env:TEMP
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$nombreBase = 'Instana-Compatibilidad-{0}-{1}' -f $env:COMPUTERNAME, $timestamp
$rutaTrabajo = Join-Path $baseOutput $nombreBase
$rutaZip = Join-Path $baseOutput ($nombreBase + '.zip')

New-Item -ItemType Directory -Path $rutaTrabajo -Force | Out-Null

# -----------------------------------------------------------------------------
# 01. Sistema operativo, CPU y memoria
# -----------------------------------------------------------------------------

$sistema = @()
try {
    $os = Get-WmiObject -Class Win32_OperatingSystem
    $computer = Get-WmiObject -Class Win32_ComputerSystem
    $cpu = @(Get-WmiObject -Class Win32_Processor)
    $osFamily = Get-WindowsServerFamily -Caption ([string]$os.Caption)
    $osSupported = (-not [string]::IsNullOrWhiteSpace($osFamily)) -and ([string]$os.OSArchitecture -match '64')
    $osSupportStatus = 'REQUIERE VALIDACION CON IBM'
    if ($osSupported) {
        if ($osFamily -eq 'Windows Server 2012' -or $osFamily -eq 'Windows Server 2012 R2') {
            $osSupportStatus = 'INCLUIDO EN MATRIZ - VALIDAR CICLO DE VIDA'
        }
        else {
            $osSupportStatus = 'SOPORTADO'
        }
    }

    $availableMemoryGB = 0
    if ($null -ne $os.FreePhysicalMemory) {
        $availableMemoryGB = [Math]::Round(([double]$os.FreePhysicalMemory * 1KB / 1GB), 2)
    }

    $logicalProcessors = 0
    foreach ($processor in $cpu) {
        if ($null -ne $processor.NumberOfLogicalProcessors) {
            $logicalProcessors += [int]$processor.NumberOfLogicalProcessors
        }
        elseif ($null -ne $processor.NumberOfCores) {
            $logicalProcessors += [int]$processor.NumberOfCores
        }
    }

    $sistema = @(
        (New-Object PSObject -Property @{
            Servidor                  = $env:COMPUTERNAME
            SistemaOperativo          = [string]$os.Caption
            FamiliaDetectada          = $osFamily
            VersionSO                 = [string]$os.Version
            BuildSO                   = [string]$os.BuildNumber
            ArquitecturaSO            = [string]$os.OSArchitecture
            CompatibilidadSOInstana   = $osSupportStatus
            MemoriaTotalGB            = [Math]::Round(([double]$computer.TotalPhysicalMemory / 1GB), 2)
            MemoriaDisponibleGB       = $availableMemoryGB
            ProcesadoresLogicos       = $logicalProcessors
            CPU                       = if ($cpu.Count -gt 0) { [string]$cpu[0].Name } else { '' }
            ArquitecturaCPU           = if ($cpu.Count -gt 0) { [string]$cpu[0].AddressWidth } else { '' }
            PowerShell                = $PSVersionTable.PSVersion.ToString()
            ProcesoPowerShell64Bits   = [Environment]::Is64BitProcess
            EsAdministrador           = $esAdministrador
            FechaDiagnostico          = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            FechaMatrizSoporte        = $SupportMatrixDate
        })
    )
}
catch {
    Add-DiagnosticError -Seccion 'Sistema' -Mensaje $_.Exception.Message
}
Export-CsvSafe -Datos $sistema -Ruta (Join-Path $rutaTrabajo '01-Sistema.csv') -MensajeVacio 'No se pudo recopilar informacion del sistema'

# -----------------------------------------------------------------------------
# 02. Prerequisitos de capacidad informativos para monitoreo .NET
# -----------------------------------------------------------------------------

$prerequisitos = New-Object System.Collections.ArrayList
if (@($sistema).Count -gt 0) {
    [void]$prerequisitos.Add((New-Object PSObject -Property @{
        Requisito   = 'Sistema operativo Windows soportado en x64/amd64'
        Detectado   = ($sistema[0].SistemaOperativo + ' / ' + $sistema[0].ArquitecturaSO)
        Resultado   = $sistema[0].CompatibilidadSOInstana
        Impacto     = 'Compatibilidad base del agente y sensores Windows'
    }))

    [void]$prerequisitos.Add((New-Object PSObject -Property @{
        Requisito   = '4 o mas CPU para monitoreo .NET optimo'
        Detectado   = [string]$sistema[0].ProcesadoresLogicos
        Resultado   = 'INFORMATIVO'
        Impacto     = 'Dato de contexto; no modifica el resultado de compatibilidad'
    }))

    [void]$prerequisitos.Add((New-Object PSObject -Property @{
        Requisito   = '8 GB o mas de memoria disponible para monitoreo .NET'
        Detectado   = ([string]$sistema[0].MemoriaDisponibleGB + ' GB disponibles; ' + [string]$sistema[0].MemoriaTotalGB + ' GB totales')
        Resultado   = 'INFORMATIVO'
        Impacto     = 'Dato de contexto; no modifica el resultado de compatibilidad'
    }))
}
Export-CsvSafe -Datos @($prerequisitos) -Ruta (Join-Path $rutaTrabajo '02-Prerequisitos.csv') -MensajeVacio 'No fue posible evaluar prerrequisitos'

# -----------------------------------------------------------------------------
# 03-06. IIS, pools, sitios y aplicaciones
# -----------------------------------------------------------------------------

$iisVersion = @()
$appPools = New-Object System.Collections.ArrayList
$sitios = New-Object System.Collections.ArrayList
$aplicaciones = New-Object System.Collections.ArrayList

try {
    $iisRegistryPath = 'HKLM:\SOFTWARE\Microsoft\InetStp'
    if (Test-Path -LiteralPath $iisRegistryPath) {
        $iisRegistry = Get-ItemProperty -LiteralPath $iisRegistryPath
        $iisVersion = @(
            (New-Object PSObject -Property @{
                Instalado     = $true
                VersionString = [string]$iisRegistry.VersionString
                MajorVersion  = [string]$iisRegistry.MajorVersion
                MinorVersion  = [string]$iisRegistry.MinorVersion
                SoporteInstana = 'SOPORTADO COMO TECNOLOGIA MICROSOFT IIS EN WINDOWS SOPORTADO'
            })
        )
    }
    else {
        $iisVersion = @(
            (New-Object PSObject -Property @{
                Instalado     = $false
                VersionString = ''
                MajorVersion  = ''
                MinorVersion  = ''
                SoporteInstana = 'NO APLICA - IIS NO DETECTADO'
            })
        )
    }
}
catch {
    Add-DiagnosticError -Seccion 'IIS-Version' -Mensaje $_.Exception.Message
}
Export-CsvSafe -Datos $iisVersion -Ruta (Join-Path $rutaTrabajo '03-IIS-Version.csv') -MensajeVacio 'No se pudo validar IIS'

if (@($iisVersion).Count -gt 0 -and $iisVersion[0].Instalado -eq $true) {
    try {
        $mwaPath = Join-Path $env:windir 'System32\inetsrv\Microsoft.Web.Administration.dll'
        if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
            $mwaPath = Join-Path $env:windir 'Sysnative\inetsrv\Microsoft.Web.Administration.dll'
        }

        if (-not (Test-Path -LiteralPath $mwaPath -PathType Leaf)) {
            throw ('No se encontro Microsoft.Web.Administration.dll en ' + $mwaPath)
        }

        Add-Type -Path $mwaPath
        $serverManager = New-Object Microsoft.Web.Administration.ServerManager

        foreach ($pool in $serverManager.ApplicationPools) {
            $managedRuntime = [string]$pool.ManagedRuntimeVersion
            if ([string]::IsNullOrWhiteSpace($managedRuntime)) {
                $managedRuntimeDisplay = 'No Managed Code'
            }
            else {
                $managedRuntimeDisplay = $managedRuntime
            }

            [void]$appPools.Add((New-Object PSObject -Property @{
                ApplicationPool = [string]$pool.Name
                Estado          = [string]$pool.State
                CLR             = $managedRuntimeDisplay
                Pipeline        = [string]$pool.ManagedPipelineMode
                Habilita32Bits  = [string]$pool.Enable32BitAppOnWin64
                Inicio          = [string]$pool.StartMode
                Identidad       = [string]$pool.ProcessModel.IdentityType
            }))
        }

        foreach ($site in $serverManager.Sites) {
            $bindings = New-Object System.Collections.ArrayList
            foreach ($binding in $site.Bindings) {
                [void]$bindings.Add(([string]$binding.Protocol + ':' + [string]$binding.BindingInformation))
            }

            [void]$sitios.Add((New-Object PSObject -Property @{
                Sitio      = [string]$site.Name
                Id         = [string]$site.Id
                Estado     = [string]$site.State
                AutoInicio = [string]$site.ServerAutoStart
                Bindings   = (@($bindings) -join '; ')
            }))

            foreach ($application in $site.Applications) {
                $physicalPath = ''
                foreach ($virtualDirectory in $application.VirtualDirectories) {
                    if ([string]$virtualDirectory.Path -eq '/') {
                        $physicalPath = [string]$virtualDirectory.PhysicalPath
                        break
                    }
                }

                $applicationName = [string]$site.Name + [string]$application.Path
                [void]$aplicaciones.Add((New-Object PSObject -Property @{
                    Sitio           = [string]$site.Name
                    Aplicacion      = $applicationName
                    PathIIS         = [string]$application.Path
                    ApplicationPool = [string]$application.ApplicationPoolName
                    RutaFisica      = $physicalPath
                }))
            }
        }

        $serverManager.Dispose()
    }
    catch {
        Add-DiagnosticError -Seccion 'IIS-Microsoft.Web.Administration' -Mensaje $_.Exception.Message
    }
}

Export-CsvSafe -Datos @($appPools) -Ruta (Join-Path $rutaTrabajo '04-IIS-ApplicationPools.csv') -MensajeVacio 'No se encontraron Application Pools o IIS no esta instalado'
Export-CsvSafe -Datos @($sitios) -Ruta (Join-Path $rutaTrabajo '05-IIS-Sitios.csv') -MensajeVacio 'No se encontraron sitios IIS o IIS no esta instalado'
Export-CsvSafe -Datos @($aplicaciones) -Ruta (Join-Path $rutaTrabajo '06-IIS-Aplicaciones.csv') -MensajeVacio 'No se encontraron aplicaciones IIS o IIS no esta instalado'

# -----------------------------------------------------------------------------
# 07. .NET Framework instalado en el servidor
# -----------------------------------------------------------------------------

$dotNetFramework = New-Object System.Collections.ArrayList
$dotNetRelease = $null
$dotNet45PlusVersion = 'No detectado'
$dotNetFrameworkHostSupported = $false

try {
    $ndpRoot = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP'
    if (Test-Path -LiteralPath $ndpRoot) {
        foreach ($key in @(Get-ChildItem -LiteralPath $ndpRoot -Recurse -ErrorAction SilentlyContinue)) {
            try {
                $properties = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
                if ($null -ne $properties -and ($null -ne $properties.Version -or $null -ne $properties.Release)) {
                    $detected = ''
                    if ($null -ne $properties.Release) {
                        $detected = Get-DotNetFramework45PlusVersion -Release ([int]$properties.Release)
                    }
                    else {
                        $detected = [string]$properties.Version
                    }

                    [void]$dotNetFramework.Add((New-Object PSObject -Property @{
                        RegistryPath = [string]$key.Name
                        Version      = [string]$properties.Version
                        Release      = [string]$properties.Release
                        ServicePack  = [string]$properties.SP
                        Install      = [string]$properties.Install
                        DetectadaComo = $detected
                    }))
                }
            }
            catch {
                # Se omiten subclaves sin valores relevantes.
            }
        }
    }

    $fullKeyPath = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
    if (Test-Path -LiteralPath $fullKeyPath) {
        $fullKey = Get-ItemProperty -LiteralPath $fullKeyPath
        if ($null -ne $fullKey.Release) {
            $dotNetRelease = [int]$fullKey.Release
            $dotNet45PlusVersion = Get-DotNetFramework45PlusVersion -Release $dotNetRelease
            if ($dotNetRelease -ge 379893) {
                $dotNetFrameworkHostSupported = $true
            }
        }
    }
}
catch {
    Add-DiagnosticError -Seccion 'DotNetFramework' -Mensaje $_.Exception.Message
}
Export-CsvSafe -Datos @($dotNetFramework) -Ruta (Join-Path $rutaTrabajo '07-DotNet-Framework.csv') -MensajeVacio 'No se detectaron versiones de .NET Framework en el registro'

# -----------------------------------------------------------------------------
# 08. Runtimes .NET modernos instalados
# -----------------------------------------------------------------------------

$dotNetRuntimes = New-Object System.Collections.ArrayList
try {
    $dotnetRoots = New-Object System.Collections.ArrayList
    if (-not [string]::IsNullOrWhiteSpace([string]$env:ProgramFiles)) {
        [void]$dotnetRoots.Add((Join-Path $env:ProgramFiles 'dotnet\shared'))
    }
    if (-not [string]::IsNullOrWhiteSpace([string]${env:ProgramFiles(x86)})) {
        [void]$dotnetRoots.Add((Join-Path ${env:ProgramFiles(x86)} 'dotnet\shared'))
    }
    $dotnetRoots = @($dotnetRoots | Sort-Object -Unique)

    foreach ($root in $dotnetRoots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }

        foreach ($runtimeDirectory in @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer })) {
            foreach ($versionDirectory in @(Get-ChildItem -LiteralPath $runtimeDirectory.FullName -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer })) {
                $versionObject = Convert-ToVersionSafe -Texto $versionDirectory.Name
                $runtimeSupport = 'NO IDENTIFICADO'
                if ($null -ne $versionObject) {
                    if ($versionObject.Major -ge $MinimumModernDotNetMajor) {
                        if ($versionObject.Major -eq 9) {
                            $runtimeSupport = 'SOPORTADO CON LIMITACION DE PROFILING'
                        }
                        else {
                            $runtimeSupport = 'SOPORTADO'
                        }
                    }
                    elseif ($versionObject.Major -eq 2 -or $versionObject.Major -eq 3) {
                        $runtimeSupport = 'DEPRECADO'
                    }
                    else {
                        $runtimeSupport = 'NO INCLUIDO EN SOPORTE ACTUAL'
                    }
                }

                [void]$dotNetRuntimes.Add((New-Object PSObject -Property @{
                    Runtime        = [string]$runtimeDirectory.Name
                    Version        = [string]$versionDirectory.Name
                    Ruta           = [string]$versionDirectory.FullName
                    SoporteInstana = $runtimeSupport
                }))
            }
        }
    }
}
catch {
    Add-DiagnosticError -Seccion 'DotNetRuntimes' -Mensaje $_.Exception.Message
}
Export-CsvSafe -Datos @($dotNetRuntimes) -Ruta (Join-Path $rutaTrabajo '08-DotNet-Runtimes.csv') -MensajeVacio 'No se detectaron runtimes .NET modernos instalados'

# -----------------------------------------------------------------------------
# 09. Evidencia de version por aplicacion
# -----------------------------------------------------------------------------

$frameworkEvidence = New-Object System.Collections.ArrayList
foreach ($application in @($aplicaciones)) {
    try {
        foreach ($evidence in @(Get-ApplicationFrameworkEvidence -Aplicacion $application.Aplicacion -RutaFisica $application.RutaFisica)) {
            [void]$frameworkEvidence.Add($evidence)
        }
    }
    catch {
        Add-DiagnosticError -Seccion ('Aplicacion-' + $application.Aplicacion) -Mensaje $_.Exception.Message
    }
}
Export-CsvSafe -Datos @($frameworkEvidence) -Ruta (Join-Path $rutaTrabajo '09-Aplicaciones-Evidencia-Runtime.csv') -MensajeVacio 'No se encontraron aplicaciones o indicadores de runtime'

# -----------------------------------------------------------------------------
# 10. SQL Server local
# -----------------------------------------------------------------------------

$sqlInstances = New-Object System.Collections.ArrayList
try {
    $instanceRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server\Instance Names\SQL'
    )

    foreach ($instanceRoot in $instanceRoots) {
        if (-not (Test-Path -LiteralPath $instanceRoot)) { continue }

        $instanceMap = Get-ItemProperty -LiteralPath $instanceRoot
        foreach ($property in $instanceMap.PSObject.Properties) {
            if ($property.Name -like 'PS*') { continue }

            $instanceName = [string]$property.Name
            $instanceId = [string]$property.Value
            $setupPaths = @(
                ('HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\{0}\Setup' -f $instanceId),
                ('HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server\{0}\Setup' -f $instanceId)
            )

            $version = ''
            $edition = ''
            foreach ($setupPath in $setupPaths) {
                if (Test-Path -LiteralPath $setupPath) {
                    $setup = Get-ItemProperty -LiteralPath $setupPath
                    if ($null -ne $setup.Version) { $version = [string]$setup.Version }
                    if ($null -ne $setup.Edition) { $edition = [string]$setup.Edition }
                    break
                }
            }

            $sqlYear = ''
            $support = 'VERSION NO IDENTIFICADA'
            $versionObject = Convert-ToVersionSafe -Texto $version
            if ($null -ne $versionObject) {
                switch ($versionObject.Major) {
                    13 { $sqlYear = '2016' }
                    14 { $sqlYear = '2017' }
                    15 { $sqlYear = '2019' }
                    16 { $sqlYear = '2022' }
                    17 { $sqlYear = '2025' }
                    default { $sqlYear = 'No soportada o no identificada' }
                }

                if ($sqlYear -match '^20\d\d$' -and $SupportedSqlYears -contains [int]$sqlYear) {
                    $support = 'SOPORTADO'
                }
                else {
                    $support = 'NO INCLUIDO EN MATRIZ ACTUAL'
                }
            }

            [void]$sqlInstances.Add((New-Object PSObject -Property @{
                Instancia       = $instanceName
                InstanceId      = $instanceId
                VersionProducto = $version
                VersionSQL      = $sqlYear
                Edicion         = $edition
                SoporteInstana  = $support
            }))
        }
    }
}
catch {
    Add-DiagnosticError -Seccion 'SQLServer' -Mensaje $_.Exception.Message
}
Export-CsvSafe -Datos @($sqlInstances) -Ruta (Join-Path $rutaTrabajo '10-SQL-Server.csv') -MensajeVacio 'No se detectaron instancias SQL Server locales; no aplica en este servidor'

# -----------------------------------------------------------------------------
# 11. Evaluacion de compatibilidad por aplicacion
# -----------------------------------------------------------------------------

$applicationAssessment = New-Object System.Collections.ArrayList

foreach ($application in @($aplicaciones)) {
    $pool = @($appPools | Where-Object { $_.ApplicationPool -eq $application.ApplicationPool } | Select-Object -First 1)
    $poolClr = ''
    if ($pool.Count -gt 0) { $poolClr = [string]$pool[0].CLR }

    $appEvidence = @($frameworkEvidence | Where-Object { $_.Aplicacion -eq $application.Aplicacion })
    $runtimeEvidenceAll = @($appEvidence | Where-Object {
        $_.Indicador -match 'targetFramework|supportedRuntime|TargetFrameworkAttribute|^tfm$|^framework$|^frameworks$|^includedFrameworks$'
    })
    $hostingEvidence = @($appEvidence | Where-Object { $_.Indicador -eq 'aspNetCore hostingModel' } | Select-Object -First 1)
    $processPathEvidence = @($appEvidence | Where-Object { $_.Indicador -eq 'aspNetCore processPath' } | Select-Object -First 1)

    # Se priorizan web.config y runtimeconfig.json. Los metadatos de ensamblados se usan
    # solo como respaldo, evitando que una libreria secundaria cambie el resultado de la aplicacion.
    $runtimeEvidencePrimary = @($runtimeEvidenceAll | Where-Object { $_.Fuente -ne 'Assembly TargetFrameworkAttribute' })
    $runtimeEvidence = $runtimeEvidencePrimary
    if ($runtimeEvidence.Count -eq 0) {
        $runtimeEvidence = @($runtimeEvidenceAll | Where-Object { $_.Fuente -eq 'Assembly TargetFrameworkAttribute' })
    }

    $classifications = New-Object System.Collections.ArrayList
    foreach ($evidence in $runtimeEvidence) {
        $classification = Get-TargetFrameworkClassification -Valor ([string]$evidence.Valor)
        [void]$classifications.Add((New-Object PSObject -Property @{
            Fuente    = [string]$evidence.Fuente
            Indicador = [string]$evidence.Indicador
            Valor     = [string]$evidence.Valor
            Familia   = [string]$classification.Familia
            Version   = [string]$classification.Version
            Estado    = [string]$classification.Estado
            Sustento  = [string]$classification.Sustento
        }))
    }

    $supportedModern = @($classifications | Where-Object { $_.Familia -eq '.NET' -and $_.Estado -eq 'SOPORTADO' })
    $limitedModern = @($classifications | Where-Object { $_.Familia -eq '.NET' -and $_.Estado -eq 'SOPORTADO CON LIMITACION' })
    $deprecatedModern = @($classifications | Where-Object { $_.Familia -eq '.NET' -and $_.Estado -eq 'DEPRECADO' })
    $unsupportedModern = @($classifications | Where-Object { $_.Familia -eq '.NET' -and $_.Estado -eq 'NO SOPORTADO' })
    $supportedFramework = @($classifications | Where-Object { $_.Familia -eq '.NET Framework' -and $_.Estado -eq 'SOPORTADO' })
    $legacyFramework = @($classifications | Where-Object { $_.Familia -eq '.NET Framework' -and $_.Estado -eq 'TARGET ANTERIOR AL MINIMO' })

    $rutaAplicacionExpandida = [Environment]::ExpandEnvironmentVariables([string]$application.RutaFisica)
    $hasApplicationArtifacts = $false
    $pathAccessible = $false
    if (-not [string]::IsNullOrWhiteSpace($rutaAplicacionExpandida) -and (Test-Path -LiteralPath $rutaAplicacionExpandida -PathType Container)) {
        $pathAccessible = $true
        if (Test-Path -LiteralPath (Join-Path $rutaAplicacionExpandida 'web.config') -PathType Leaf) {
            $hasApplicationArtifacts = $true
        }
        elseif (@(Get-ChildItem -LiteralPath $rutaAplicacionExpandida -Filter '*.runtimeconfig.json' -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }).Count -gt 0) {
            $hasApplicationArtifacts = $true
        }
        elseif (Test-Path -LiteralPath (Join-Path $rutaAplicacionExpandida 'bin') -PathType Container) {
            $hasApplicationArtifacts = $true
        }
    }

    $compatibility = 'REQUIERE VALIDACION TECNICA'
    $clientLevel = 'REVISION TECNICA'
    $technology = 'No identificada'
    $reason = 'No se identifico con precision el runtime utilizado por la aplicacion.'
    $observation = 'La falta de evidencia no se interpreta como incompatibilidad.'
    $recommendedAction = 'Revisar el detalle recopilado o confirmar el runtime con el equipo de aplicacion.'
    $confidence = 'BAJA'

    $meaningfulModernCount = $supportedModern.Count + $limitedModern.Count + $deprecatedModern.Count + $unsupportedModern.Count
    $meaningfulFrameworkCount = $supportedFramework.Count + $legacyFramework.Count
    $hasMixedFamilies = ($meaningfulModernCount -gt 0 -and $meaningfulFrameworkCount -gt 0)
    $hasMixedModernStates = @($classifications | Where-Object { $_.Familia -eq '.NET' -and $_.Estado -ne 'NO DETERMINADO' } | Select-Object -ExpandProperty Estado -Unique).Count -gt 1

    $hasDotNetIndicator = ($runtimeEvidenceAll.Count -gt 0 -or $hostingEvidence.Count -gt 0 -or $processPathEvidence.Count -gt 0)

    if (@($classifications | Where-Object { $_.Estado -ne 'NO DETERMINADO' }).Count -eq 0 -and -not $hasDotNetIndicator) {
        if (-not $pathAccessible -and -not [string]::IsNullOrWhiteSpace($rutaAplicacionExpandida)) {
            $technology = 'Aplicacion IIS no evaluada'
            $compatibility = 'REQUIERE VALIDACION TECNICA'
            $clientLevel = 'EVIDENCIA PARCIAL'
            $reason = 'La ruta fisica configurada en IIS no pudo leerse durante la ejecucion.'
            $observation = 'Esto no implica que la aplicacion sea incompatible.'
            $recommendedAction = 'Ejecutar como administrador o validar el acceso a la ruta y repetir la recopilacion.'
        }
        else {
            $technology = 'No se identifico aplicacion .NET'
            $compatibility = 'NO APLICA'
            $clientLevel = 'NO APLICA'
            $reason = 'La ruta IIS no contiene evidencia de una aplicacion .NET desplegada.'
            $observation = ''
            $recommendedAction = 'No requiere una accion de compatibilidad .NET.'
            $confidence = 'ALTA'
        }
    }
    elseif ($hasMixedFamilies -or $hasMixedModernStates) {
        $technology = 'Multiples runtimes detectados'
        $compatibility = 'REQUIERE VALIDACION TECNICA'
        $clientLevel = 'REVISION TECNICA'
        $reason = 'Se encontraron indicadores de mas de una familia o estado de runtime dentro de la misma ruta IIS.'
        $observation = 'Puede corresponder a componentes auxiliares, herramientas de despliegue o aplicaciones compartiendo una ruta.'
        $recommendedAction = 'Revisar el proceso principal y su runtimeconfig.json antes de emitir una conclusion por aplicacion.'
        $confidence = 'MEDIA'
    }
    elseif ($unsupportedModern.Count -gt 0) {
        $technology = '.NET / .NET Core'
        $compatibility = 'REQUIERE MODERNIZACION PARA APM'
        $clientLevel = 'RECOMENDACION DE MODERNIZACION'
        $reason = 'La version detectada no se encuentra incluida en el rango actual de soporte de runtime.'
        $observation = 'La plataforma Windows e IIS puede continuar siendo compatible; la recomendacion aplica a la cobertura APM de esta aplicacion.'
        $recommendedAction = 'Planificar la actualizacion a una version .NET soportada y vigente.'
        $confidence = 'ALTA'
    }
    elseif ($deprecatedModern.Count -gt 0) {
        $technology = '.NET Core'
        $compatibility = 'COMPATIBLE CON RECOMENDACION'
        $clientLevel = 'FAVORABLE CON RECOMENDACION'
        $reason = 'La version .NET Core 2.x o 3.x aparece con estado deprecado en la documentacion de Instana.'
        $observation = 'No se clasifica como incompatibilidad. Se recomienda modernizacion para continuidad de soporte.'
        $recommendedAction = 'Mantener la evaluacion como viable y definir un plan de actualizacion del runtime.'
        $confidence = 'ALTA'
    }
    elseif ($limitedModern.Count -gt 0) {
        $technology = '.NET'
        $compatibility = 'COMPATIBLE CON LIMITACION DOCUMENTADA'
        $clientLevel = 'FAVORABLE CON LIMITACION'
        $reason = 'La instrumentacion del runtime esta soportada, con una limitacion funcional documentada.'
        $observation = 'Para .NET 9, el profiling no esta soportado actualmente; la instrumentacion si esta soportada.'
        $recommendedAction = 'Considerar la limitacion de profiling al definir el alcance funcional.'
        $confidence = 'ALTA'
    }
    elseif ($supportedModern.Count -gt 0) {
        $technology = '.NET'
        $compatibility = 'COMPATIBLE'
        $clientLevel = 'FAVORABLE'
        $reason = 'Se identifico .NET 5.0 o posterior dentro del soporte GA.'
        $observation = ''
        $recommendedAction = 'No se requiere una accion adicional para compatibilidad del runtime.'
        $confidence = 'ALTA'

        if ($poolClr -ne 'No Managed Code') {
            $compatibility = 'COMPATIBLE CON RECOMENDACION DE CONFIGURACION'
            $clientLevel = 'FAVORABLE CON RECOMENDACION'
            $observation = 'Para aplicaciones .NET 5 o posteriores hospedadas en IIS, IBM documenta el uso de Application Pool en No Managed Code.'
            $recommendedAction = 'Validar la configuracion del Application Pool antes de la habilitacion APM.'
        }
        else {
            $observation = 'En No Managed Code, la trazabilidad de aplicacion es soportada; ciertas metricas IIS del pool y worker process no estan disponibles.'
        }
    }
    elseif ($supportedFramework.Count -gt 0) {
        $technology = '.NET Framework'
        if ($dotNetFrameworkHostSupported) {
            $compatibility = 'COMPATIBLE'
            $clientLevel = 'FAVORABLE'
            $reason = 'La aplicacion y el runtime efectivo cumplen .NET Framework 4.5.2 o posterior.'
            $observation = ''
            $recommendedAction = 'No se requiere una accion adicional para compatibilidad del runtime.'
            $confidence = 'ALTA'
        }
        else {
            $compatibility = 'REQUIERE VALIDACION TECNICA'
            $clientLevel = 'EVIDENCIA PARCIAL'
            $reason = 'La aplicacion declara una version soportada, pero el registro del servidor no permitio confirmar el runtime efectivo.'
            $observation = 'La evidencia incompleta no se interpreta como incompatibilidad.'
            $recommendedAction = 'Completar la lectura del registro de .NET Framework y repetir la evaluacion.'
            $confidence = 'MEDIA'
        }
    }
    elseif ($legacyFramework.Count -gt 0) {
        $technology = '.NET Framework'
        if ($poolClr -eq 'v4.0' -and $dotNetFrameworkHostSupported) {
            $compatibility = 'COMPATIBLE CON RECOMENDACION'
            $clientLevel = 'FAVORABLE CON RECOMENDACION'
            $reason = 'La aplicacion declara un target anterior a 4.5.2, pero se ejecuta en CLR v4.0 y el servidor dispone de un runtime .NET Framework soportado.'
            $observation = 'Se recomienda confirmar el target efectivo y las librerias principales; no se clasifica automaticamente como incompatibilidad.'
            $recommendedAction = 'Validar el target efectivo con el equipo de desarrollo y mantener evidencia del runtime instalado.'
            $confidence = 'MEDIA'
        }
        elseif ($poolClr -eq 'v2.0') {
            $compatibility = 'REQUIERE MODERNIZACION PARA APM'
            $clientLevel = 'RECOMENDACION DE MODERNIZACION'
            $reason = 'El Application Pool usa CLR v2.0, asociado normalmente a .NET Framework 2.0, 3.0 o 3.5.'
            $observation = 'La limitacion aplica a la cobertura APM de esta aplicacion, no a la compatibilidad completa del servidor.'
            $recommendedAction = 'Confirmar el target y planificar una actualizacion a .NET Framework 4.5.2 o posterior.'
            $confidence = 'ALTA'
        }
        else {
            $compatibility = 'REQUIERE VALIDACION TECNICA'
            $clientLevel = 'REVISION TECNICA'
            $reason = 'Se detecto un target anterior al minimo, pero no fue posible determinar el runtime efectivo con certeza.'
            $observation = 'No se emite una conclusion negativa sin confirmar el runtime real.'
            $recommendedAction = 'Confirmar el CLR y runtime efectivo de la aplicacion.'
            $confidence = 'MEDIA'
        }
    }
    elseif ($poolClr -eq 'v2.0') {
        $technology = '.NET Framework 2.0-3.5 probable'
        $compatibility = 'REQUIERE MODERNIZACION PARA APM'
        $clientLevel = 'RECOMENDACION DE MODERNIZACION'
        $reason = 'No se encontro un target preciso y el Application Pool utiliza CLR v2.0.'
        $observation = 'El resultado se limita a la aplicacion; no invalida la compatibilidad del servidor.'
        $recommendedAction = 'Confirmar el target exacto y evaluar la modernizacion del runtime.'
        $confidence = 'MEDIA'
    }
    elseif ($poolClr -eq 'v4.0' -and $dotNetFrameworkHostSupported) {
        $technology = '.NET Framework probable'
        $compatibility = 'COMPATIBLE CON RECOMENDACION'
        $clientLevel = 'FAVORABLE CON RECOMENDACION'
        $reason = 'El pool utiliza CLR v4.0 y el servidor dispone de .NET Framework 4.5.2 o posterior, aunque no se encontro el target exacto.'
        $observation = 'La compatibilidad es favorable a nivel de runtime efectivo; queda pendiente precisar el target de compilacion.'
        $recommendedAction = 'Conservar la evidencia y confirmar el target cuando el equipo de aplicacion lo tenga disponible.'
        $confidence = 'MEDIA'
    }
    elseif ($poolClr -eq 'No Managed Code') {
        $technology = '.NET moderno probable o aplicacion nativa'
        $compatibility = 'REQUIERE VALIDACION TECNICA'
        $clientLevel = 'EVIDENCIA PARCIAL'
        $reason = 'El pool utiliza No Managed Code, pero no se encontro un indicador suficiente para identificar el runtime.'
        $observation = 'No se clasifica como incompatibilidad.'
        $recommendedAction = 'Confirmar el runtime mediante runtimeconfig.json o el artefacto de despliegue.'
        $confidence = 'BAJA'
    }

    $runtimeValues = @($classifications | Where-Object { $_.Estado -ne 'NO DETERMINADO' } | ForEach-Object { $_.Valor } | Sort-Object -Unique)
    $runtimeSummary = 'No identificado'
    if ($runtimeValues.Count -gt 0) { $runtimeSummary = $runtimeValues -join '; ' }

    $hostingModel = 'No identificado'
    if ($hostingEvidence.Count -gt 0) { $hostingModel = [string]$hostingEvidence[0].Valor }

    $processPath = 'No identificado'
    if ($processPathEvidence.Count -gt 0) { $processPath = [string]$processPathEvidence[0].Valor }

    [void]$applicationAssessment.Add((New-Object PSObject -Property @{
        Aplicacion             = [string]$application.Aplicacion
        Sitio                  = [string]$application.Sitio
        ApplicationPool        = [string]$application.ApplicationPool
        CLRPool                = $poolClr
        TecnologiaIdentificada = $technology
        RuntimeIdentificado    = $runtimeSummary
        HostingModel           = $hostingModel
        ProcessPath            = $processPath
        CompatibilidadInstana  = $compatibility
        ResultadoCliente       = $clientLevel
        ConfianzaEvidencia     = $confidence
        Sustento               = $reason
        Observacion            = $observation
        AccionRecomendada       = $recommendedAction
    }))
}

Export-CsvSafe -Datos @($applicationAssessment) -Ruta (Join-Path $rutaTrabajo '11-Evaluacion-Aplicaciones.csv') -MensajeVacio 'No se encontraron aplicaciones IIS para evaluar'

# -----------------------------------------------------------------------------
# 12. Matriz consolidada de tecnologias detectadas
# -----------------------------------------------------------------------------

$technologyMatrix = New-Object System.Collections.ArrayList

if (@($sistema).Count -gt 0) {
    [void]$technologyMatrix.Add((New-Object PSObject -Property @{
        Capa          = 'Sistema operativo'
        Tecnologia    = [string]$sistema[0].SistemaOperativo
        Version       = [string]$sistema[0].VersionSO
        Arquitectura  = [string]$sistema[0].ArquitecturaSO
        Resultado     = [string]$sistema[0].CompatibilidadSOInstana
        Criterio      = 'Windows Server 2012, 2012 R2, 2016, 2019, 2022 y 2025 sobre x64/amd64.'
    }))
}

if (@($iisVersion).Count -gt 0 -and $iisVersion[0].Instalado -eq $true) {
    $iisResult = 'SOPORTADO'
    if (@($sistema).Count -eq 0 -or $sistema[0].CompatibilidadSOInstana -ne 'SOPORTADO') {
        $iisResult = 'CONDICIONADO AL SISTEMA OPERATIVO'
    }

    [void]$technologyMatrix.Add((New-Object PSObject -Property @{
        Capa          = 'Servidor web'
        Tecnologia    = 'Microsoft IIS'
        Version       = [string]$iisVersion[0].VersionString
        Arquitectura  = if (@($sistema).Count -gt 0) { [string]$sistema[0].ArquitecturaSO } else { '' }
        Resultado     = $iisResult
        Criterio      = 'Instana dispone de sensor para Microsoft IIS en sistemas Windows soportados.'
    }))
}

if ($dotNet45PlusVersion -ne 'No detectado') {
    [void]$technologyMatrix.Add((New-Object PSObject -Property @{
        Capa          = 'Runtime'
        Tecnologia    = '.NET Framework'
        Version       = $dotNet45PlusVersion
        Arquitectura  = 'Windows'
        Resultado     = if ($dotNetFrameworkHostSupported) { 'SOPORTADO' } else { 'NO SOPORTADO' }
        Criterio      = '.NET Framework 4.5.2 o posterior.'
    }))
}

foreach ($runtime in @($dotNetRuntimes | Sort-Object Runtime, Version -Unique)) {
    [void]$technologyMatrix.Add((New-Object PSObject -Property @{
        Capa          = 'Runtime'
        Tecnologia    = [string]$runtime.Runtime
        Version       = [string]$runtime.Version
        Arquitectura  = 'Windows'
        Resultado     = [string]$runtime.SoporteInstana
        Criterio      = '.NET 5.0 o posterior: GA; .NET Core 2.x/3.x: deprecado; .NET 9: instrumentacion soportada con profiling no soportado.'
    }))
}

foreach ($sqlInstance in @($sqlInstances)) {
    [void]$technologyMatrix.Add((New-Object PSObject -Property @{
        Capa          = 'Base de datos'
        Tecnologia    = 'Microsoft SQL Server'
        Version       = ([string]$sqlInstance.VersionSQL + ' / ' + [string]$sqlInstance.VersionProducto)
        Arquitectura  = 'Local'
        Resultado     = [string]$sqlInstance.SoporteInstana
        Criterio      = 'SQL Server 2016, 2017, 2019 y 2022 explicitamente listados; SQL Server 2025 cubierto por politica de soporte de 45 dias.'
    }))
}

Export-CsvSafe -Datos @($technologyMatrix) -Ruta (Join-Path $rutaTrabajo '12-Matriz-Tecnologias.csv') -MensajeVacio 'No se pudieron consolidar tecnologias'

# -----------------------------------------------------------------------------
# Resumen ejecutivo
# -----------------------------------------------------------------------------

$osBaseCompatible = $false
$osLifecycleCondition = $false
if (@($sistema).Count -gt 0) {
    if ($sistema[0].CompatibilidadSOInstana -eq 'SOPORTADO') {
        $osBaseCompatible = $true
    }
    elseif ($sistema[0].CompatibilidadSOInstana -eq 'INCLUIDO EN MATRIZ - VALIDAR CICLO DE VIDA') {
        $osBaseCompatible = $true
        $osLifecycleCondition = $true
    }
}

$compatibleApplications = @($applicationAssessment | Where-Object { $_.CompatibilidadInstana -eq 'COMPATIBLE' }).Count
$recommendedApplications = @($applicationAssessment | Where-Object { $_.CompatibilidadInstana -match '^COMPATIBLE CON' }).Count
$modernizationApplications = @($applicationAssessment | Where-Object { $_.CompatibilidadInstana -eq 'REQUIERE MODERNIZACION PARA APM' }).Count
$technicalReviewApplications = @($applicationAssessment | Where-Object { $_.CompatibilidadInstana -eq 'REQUIERE VALIDACION TECNICA' }).Count
$notApplicableApplications = @($applicationAssessment | Where-Object { $_.CompatibilidadInstana -eq 'NO APLICA' }).Count
$evaluatedApplications = $compatibleApplications + $recommendedApplications + $modernizationApplications + $technicalReviewApplications
$collectionWarnings = @($Errores).Count

$environmentResult = 'REQUIERE VALIDACION CON IBM'
if ($osBaseCompatible) {
    if ($osLifecycleCondition) {
        $environmentResult = 'COMPATIBLE CON CONDICION DE CICLO DE VIDA'
    }
    else {
        $environmentResult = 'COMPATIBLE'
    }
}

$applicationResult = 'NO APLICA'
if ($evaluatedApplications -gt 0) {
    if ($modernizationApplications -gt 0 -or $technicalReviewApplications -gt 0) {
        $applicationResult = 'FAVORABLE CON OBSERVACIONES TECNICAS'
    }
    elseif ($recommendedApplications -gt 0) {
        $applicationResult = 'FAVORABLE CON RECOMENDACIONES'
    }
    else {
        $applicationResult = 'FAVORABLE'
    }
}

$overallResult = 'REQUIERE REVISION TECNICA'
$overallConclusion = 'La evaluacion se completo, pero la plataforma base requiere validacion adicional con IBM.'

if ($osBaseCompatible) {
    if ($modernizationApplications -gt 0 -or $technicalReviewApplications -gt 0 -or $collectionWarnings -gt 0 -or -not $esAdministrador) {
        $overallResult = 'FAVORABLE CON OBSERVACIONES'
        $overallConclusion = 'La plataforma base es compatible. Las observaciones identificadas corresponden a versiones de aplicaciones o evidencia parcial y no representan por si solas una incompatibilidad del servidor.'
    }
    elseif ($recommendedApplications -gt 0 -or $osLifecycleCondition) {
        $overallResult = 'FAVORABLE CON RECOMENDACIONES'
        $overallConclusion = 'La compatibilidad es favorable. Se documentaron recomendaciones de ciclo de vida, configuracion o modernizacion planificada.'
    }
    else {
        $overallResult = 'FAVORABLE'
        $overallConclusion = 'Las tecnologias detectadas se encuentran dentro de los criterios de soporte incorporados para IBM Instana.'
    }
}

$resumen = New-Object System.Collections.ArrayList
[void]$resumen.Add('DIAGNOSTICO DE COMPATIBILIDAD TECNOLOGICA CON IBM INSTANA')
[void]$resumen.Add(('Servidor: {0}' -f $env:COMPUTERNAME))
[void]$resumen.Add(('Fecha: {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
[void]$resumen.Add(('Matriz de soporte incorporada: {0}' -f $SupportMatrixDate))
[void]$resumen.Add('')
[void]$resumen.Add('RESULTADO EJECUTIVO')
[void]$resumen.Add('Estado de ejecucion: COMPLETADO')
[void]$resumen.Add(('Resultado de compatibilidad: {0}' -f $overallResult))
[void]$resumen.Add(('Compatibilidad del entorno: {0}' -f $environmentResult))
[void]$resumen.Add(('Evaluacion de aplicaciones: {0}' -f $applicationResult))
[void]$resumen.Add(('Conclusion: {0}' -f $overallConclusion))
[void]$resumen.Add('')

if (@($sistema).Count -gt 0) {
    [void]$resumen.Add('SERVIDOR')
    [void]$resumen.Add(('Sistema operativo: {0}' -f $sistema[0].SistemaOperativo))
    [void]$resumen.Add(('Version / build: {0} / {1}' -f $sistema[0].VersionSO, $sistema[0].BuildSO))
    [void]$resumen.Add(('Arquitectura: {0}' -f $sistema[0].ArquitecturaSO))
    [void]$resumen.Add(('Compatibilidad del sistema operativo: {0}' -f $sistema[0].CompatibilidadSOInstana))
    [void]$resumen.Add(('CPU logicos / memoria disponible: {0} / {1} GB' -f $sistema[0].ProcesadoresLogicos, $sistema[0].MemoriaDisponibleGB))
    [void]$resumen.Add('')
}

[void]$resumen.Add('TECNOLOGIAS DETECTADAS')
if (@($iisVersion).Count -gt 0 -and $iisVersion[0].Instalado -eq $true) {
    [void]$resumen.Add(('Microsoft IIS: {0} - tecnologia soportada en Windows compatible' -f $iisVersion[0].VersionString))
}
else {
    [void]$resumen.Add('Microsoft IIS: no detectado; la evaluacion IIS no aplica')
}
[void]$resumen.Add(('.NET Framework instalado: {0} - {1}' -f $dotNet45PlusVersion, $(if ($dotNetFrameworkHostSupported) { 'SOPORTADO' } else { 'NO CONFIRMADO' })))

$runtimeGroups = @($dotNetRuntimes | Group-Object Runtime)
if ($runtimeGroups.Count -gt 0) {
    foreach ($runtimeGroup in $runtimeGroups) {
        $versions = @($runtimeGroup.Group | ForEach-Object { $_.Version } | Sort-Object -Unique)
        [void]$resumen.Add(('{0}: {1}' -f $runtimeGroup.Name, ($versions -join ', ')))
    }
}
else {
    [void]$resumen.Add('.NET moderno: no detectado; no aplica si no existen aplicaciones .NET modernas')
}

if (@($sqlInstances).Count -gt 0) {
    foreach ($sqlInstance in $sqlInstances) {
        [void]$resumen.Add(('SQL Server {0} ({1}): {2}' -f $sqlInstance.VersionSQL, $sqlInstance.Instancia, $sqlInstance.SoporteInstana))
    }
}
else {
    [void]$resumen.Add('SQL Server local: no detectado; no aplica en este servidor')
}
[void]$resumen.Add('')

[void]$resumen.Add('EVALUACION POR APLICACION')
if (@($applicationAssessment).Count -eq 0) {
    [void]$resumen.Add('No se detectaron aplicaciones IIS para evaluar. Esto no representa un error.')
}
else {
    foreach ($assessment in @($applicationAssessment)) {
        [void]$resumen.Add(('- {0}' -f $assessment.Aplicacion))
        [void]$resumen.Add(('  Resultado para cliente: {0}' -f $assessment.ResultadoCliente))
        [void]$resumen.Add(('  Resultado tecnico: {0}' -f $assessment.CompatibilidadInstana))
        [void]$resumen.Add(('  Pool / CLR: {0} / {1}' -f $assessment.ApplicationPool, $assessment.CLRPool))
        [void]$resumen.Add(('  Tecnologia: {0}' -f $assessment.TecnologiaIdentificada))
        [void]$resumen.Add(('  Runtime: {0}' -f $assessment.RuntimeIdentificado))
        [void]$resumen.Add(('  Confianza de evidencia: {0}' -f $assessment.ConfianzaEvidencia))
        [void]$resumen.Add(('  Sustento: {0}' -f $assessment.Sustento))
        if (-not [string]::IsNullOrWhiteSpace([string]$assessment.Observacion)) {
            [void]$resumen.Add(('  Observacion: {0}' -f $assessment.Observacion))
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$assessment.AccionRecomendada)) {
            [void]$resumen.Add(('  Accion recomendada: {0}' -f $assessment.AccionRecomendada))
        }
    }
}
[void]$resumen.Add('')

[void]$resumen.Add('CRITERIOS DE SOPORTE UTILIZADOS')
[void]$resumen.Add('- Windows Server 2012, 2012 R2, 2016, 2019, 2022 y 2025 sobre x64/amd64.')
[void]$resumen.Add('- Windows Server 2012 y 2012 R2: incluidos en la matriz; la condicion final depende del ciclo de vida y acuerdo de soporte aplicable.')
[void]$resumen.Add('- .NET Framework 4.5.2 o posterior: soporte GA.')
[void]$resumen.Add('- .NET 5.0 o posterior: soporte GA.')
[void]$resumen.Add('- .NET Core 2.x y 3.x: soporte deprecado; se recomienda modernizacion, sin clasificarlo automaticamente como incompatibilidad.')
[void]$resumen.Add('- .NET 9: instrumentacion soportada; profiling no soportado actualmente.')
[void]$resumen.Add('- .NET 5 o posterior en IIS: No Managed Code; la trazabilidad continua disponible, con limitacion de ciertas metricas IIS del pool y worker.')
[void]$resumen.Add('- SQL Server 2016, 2017, 2019 y 2022: listados; SQL Server 2025: cubierto por la politica vigente de soporte de 45 dias.')
[void]$resumen.Add('')

[void]$resumen.Add('COMO INTERPRETAR LAS OBSERVACIONES')
[void]$resumen.Add('- Una observacion de aplicacion no invalida la compatibilidad del servidor completo.')
[void]$resumen.Add('- Evidencia parcial significa que el script no pudo leer o identificar un dato; no significa que la tecnologia sea incompatible.')
[void]$resumen.Add('- Soporte deprecado significa que la tecnologia mantiene una condicion documentada de soporte, pero se recomienda modernizacion.')
[void]$resumen.Add('- Las limitaciones documentadas se presentan como alcance funcional y no como fallas del ambiente.')
[void]$resumen.Add('')

[void]$resumen.Add('ALCANCE DEL RESULTADO')
[void]$resumen.Add('- Valida plataforma Windows, aplicaciones .NET hospedadas en IIS y SQL Server local.')
[void]$resumen.Add('- No valida agente, instrumentacion, conectividad, presencia de trazas ni aplicaciones .NET ejecutadas como servicios Windows independientes.')
[void]$resumen.Add('- No emite una conclusion negativa cuando la evidencia es contradictoria o insuficiente; la marca para revision tecnica.')
[void]$resumen.Add('- La cobertura de librerias de trazado cambia con las versiones del tracer y se valida por separado cuando forma parte del alcance funcional.')
[void]$resumen.Add('')

[void]$resumen.Add('RESUMEN CUANTITATIVO')
[void]$resumen.Add(('Aplicaciones con compatibilidad favorable: {0}' -f $compatibleApplications))
[void]$resumen.Add(('Aplicaciones favorables con recomendacion o limitacion: {0}' -f $recommendedApplications))
[void]$resumen.Add(('Aplicaciones con recomendacion de modernizacion para APM: {0}' -f $modernizationApplications))
[void]$resumen.Add(('Aplicaciones que requieren validacion tecnica adicional: {0}' -f $technicalReviewApplications))
[void]$resumen.Add(('Rutas IIS donde no aplica evaluacion .NET: {0}' -f $notApplicableApplications))
[void]$resumen.Add(('Advertencias de recopilacion: {0}' -f $collectionWarnings))

$resumen | Out-File -LiteralPath (Join-Path $rutaTrabajo '00-Resumen-Compatibilidad.txt') -Encoding UTF8

$readme = @'
CONTENIDO DEL ZIP

00-Resumen-Compatibilidad.txt
    Resultado ejecutivo. Diferencia compatibilidad del entorno, runtime de cada
    aplicacion, recomendaciones y casos de evidencia parcial.

01-Sistema.csv
    Sistema operativo, build, arquitectura, CPU, memoria y version de PowerShell.

02-Prerequisitos.csv
    Datos informativos de capacidad. Una recomendacion de capacidad no cambia por
    si sola el resultado de compatibilidad.

03-IIS-Version.csv
    Presencia y version de Microsoft IIS.

04-IIS-ApplicationPools.csv
    Application Pools, CLR, pipeline, arquitectura y estado.

05-IIS-Sitios.csv
    Sitios y bindings detectados.

06-IIS-Aplicaciones.csv
    Relacion de aplicaciones, pools y rutas fisicas.

07-DotNet-Framework.csv
    Versiones de .NET Framework instaladas.

08-DotNet-Runtimes.csv
    Runtimes .NET instalados y su estado: GA, deprecado, limitacion documentada
    o no incluido en la matriz actual.

09-Aplicaciones-Evidencia-Runtime.csv
    Indicadores de version extraidos sin copiar web.config ni datos sensibles.

10-SQL-Server.csv
    Instancias locales de SQL Server y version detectada.

11-Evaluacion-Aplicaciones.csv
    Resultado tecnico y resultado orientado al cliente por aplicacion.

12-Matriz-Tecnologias.csv
    Matriz consolidada de tecnologias y criterios aplicados.

99-Errores.csv
    Secciones que no pudieron recopilarse. Un error de lectura o una ruta no
    accesible no se interpreta automaticamente como incompatibilidad.

ALCANCE
    El diagnostico valida compatibilidad tecnologica para Windows, IIS, runtimes .NET
    detectados y SQL Server local. No valida agente Instana, instrumentacion, profiler,
    sensores, trazas, conectividad, credenciales ni servicios Windows .NET independientes.
'@
$readme | Out-File -LiteralPath (Join-Path $rutaTrabajo 'README.txt') -Encoding UTF8

Export-CsvSafe -Datos @($Errores) -Ruta (Join-Path $rutaTrabajo '99-Errores.csv') -MensajeVacio 'Sin errores durante la recopilacion'

try {
    New-ZipFile -CarpetaOrigen $rutaTrabajo -ArchivoZip $rutaZip
}
catch {
    Add-DiagnosticError -Seccion 'ZIP' -Mensaje $_.Exception.Message
    Export-CsvSafe -Datos @($Errores) -Ruta (Join-Path $rutaTrabajo '99-Errores.csv') -MensajeVacio 'Sin errores durante la recopilacion'
    throw
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor DarkGray
Write-Host 'DIAGNOSTICO DE COMPATIBILIDAD CON IBM INSTANA' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor DarkGray
Write-Host ('Servidor: {0}' -f $env:COMPUTERNAME)
Write-Host 'Estado de ejecucion: COMPLETADO' -ForegroundColor Green

if ($environmentResult -eq 'COMPATIBLE') {
    Write-Host ('Compatibilidad del entorno: {0}' -f $environmentResult) -ForegroundColor Green
}
elseif ($environmentResult -match '^COMPATIBLE CON') {
    Write-Host ('Compatibilidad del entorno: {0}' -f $environmentResult) -ForegroundColor Yellow
}
else {
    Write-Host ('Compatibilidad del entorno: {0}' -f $environmentResult) -ForegroundColor Yellow
}

if ($overallResult -eq 'FAVORABLE') {
    Write-Host ('Resultado de compatibilidad: {0}' -f $overallResult) -ForegroundColor Green
}
else {
    Write-Host ('Resultado de compatibilidad: {0}' -f $overallResult) -ForegroundColor Yellow
}

if ($evaluatedApplications -gt 0) {
    Write-Host ('Aplicaciones evaluadas: {0}' -f $evaluatedApplications)
    Write-Host ('  Compatibilidad favorable: {0}' -f $compatibleApplications) -ForegroundColor Green
    Write-Host ('  Favorables con recomendacion o limitacion: {0}' -f $recommendedApplications) -ForegroundColor Yellow
    Write-Host ('  Recomendacion de modernizacion para APM: {0}' -f $modernizationApplications) -ForegroundColor Yellow
    Write-Host ('  Requieren validacion tecnica adicional: {0}' -f $technicalReviewApplications) -ForegroundColor Yellow
}
else {
    Write-Host 'Aplicaciones .NET en IIS: no detectadas; esta capa no aplica.' -ForegroundColor DarkGray
}

if (-not $esAdministrador) {
    Write-Host ''
    Write-Host 'Nota: el script se ejecuto sin privilegios administrativos.' -ForegroundColor Yellow
    Write-Host 'Se genero el ZIP con la evidencia disponible; algunas secciones pueden quedar parciales.' -ForegroundColor Yellow
}

if ($collectionWarnings -gt 0) {
    Write-Host ''
    Write-Host ('Se registraron {0} advertencia(s) de recopilacion.' -f $collectionWarnings) -ForegroundColor Yellow
    Write-Host 'Esto no implica incompatibilidad. El detalle se encuentra en 99-Errores.csv.' -ForegroundColor DarkYellow
}

$supportedDetected = @($technologyMatrix | Where-Object { $_.Resultado -eq 'SOPORTADO' })
if ($supportedDetected.Count -gt 0) {
    Write-Host ''
    Write-Host 'Tecnologias con soporte confirmado:' -ForegroundColor Green
    foreach ($item in $supportedDetected) {
        Write-Host ('  - {0} {1}' -f $item.Tecnologia, $item.Version)
    }
}

$observationCount = $recommendedApplications + $modernizationApplications + $technicalReviewApplications
if ($observationCount -gt 0) {
    Write-Host ''
    Write-Host ('Se documentaron {0} observacion(es) de aplicacion.' -f $observationCount) -ForegroundColor Yellow
    Write-Host 'Las observaciones no invalidan por si solas la compatibilidad del servidor.' -ForegroundColor DarkYellow
    Write-Host 'El detalle tecnico y la recomendacion se encuentran dentro del ZIP.' -ForegroundColor DarkYellow
}

Write-Host ''
Write-Host ('ZIP generado: {0}' -f $rutaZip) -ForegroundColor Cyan
Write-Host 'No se realizaron cambios en el servidor. Comparta unicamente el archivo ZIP generado.' -ForegroundColor Green

if ($MantenerVentanaAbierta) {
    Write-Host ''
    Write-Host 'El resumen permanecera visible hasta que cierre esta ventana.' -ForegroundColor DarkGray
    [void](Read-Host 'Presione ENTER para finalizar')
}
