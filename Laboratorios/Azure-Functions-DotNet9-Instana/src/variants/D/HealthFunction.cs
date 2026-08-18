using System.Net;
using System.Runtime.InteropServices;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace InstanaCrashLab;

public sealed class HealthFunction
{
    [Function("Health")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequestData request)
    {
        var response = request.CreateResponse(HttpStatusCode.OK);
        await response.WriteAsJsonAsync(new
        {
            status = "OK",
            runtime = RuntimeInformation.FrameworkDescription,
            hostname = Environment.MachineName,
            timestamp = DateTimeOffset.UtcNow,
            instrumented = IsInstrumented()
        });
        return response;
    }

    [Function("Test")]
    public HttpResponseData Test(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "test")] HttpRequestData request)
    {
        var response = request.CreateResponse(HttpStatusCode.OK);
        response.WriteString("test");
        return response;
    }

    [Function("Error")]
    public HttpResponseData Error(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "error")] HttpRequestData request)
    {
        throw new InvalidOperationException("controlled exception");
    }

    private static bool IsInstrumented() =>
        Environment.GetEnvironmentVariables().Keys.Cast<object>()
            .Select(key => key.ToString() ?? string.Empty)
            .Any(key => key.Contains("INSTANA", StringComparison.OrdinalIgnoreCase) ||
                        key.Contains("PROFILER", StringComparison.OrdinalIgnoreCase));
}

