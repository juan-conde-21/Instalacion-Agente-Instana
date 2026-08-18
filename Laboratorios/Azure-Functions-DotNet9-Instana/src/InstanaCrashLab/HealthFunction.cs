using System.Net;
using System.Diagnostics;
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
    public async Task<HttpResponseData> Test(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "test")] HttpRequestData request)
    {
        await Task.Delay(25);
        var checksum = Enumerable.Range(1, 1000).Sum();
        var response = request.CreateResponse(HttpStatusCode.OK);
        await response.WriteAsJsonAsync(new
        {
            status = "OK",
            endpoint = "test",
            checksum,
            activityId = Activity.Current?.Id,
            timestamp = DateTimeOffset.UtcNow
        });
        return response;
    }

    [Function("Error")]
    public async Task<HttpResponseData> Error(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "error")] HttpRequestData request)
    {
        var response = request.CreateResponse(HttpStatusCode.InternalServerError);
        await response.WriteAsJsonAsync(new
        {
            status = "ERROR",
            endpoint = "error",
            message = "Controlled laboratory HTTP 500",
            timestamp = DateTimeOffset.UtcNow
        });
        return response;
    }

    private static bool IsInstrumented() =>
        Environment.GetEnvironmentVariables().Keys.Cast<object>()
            .Select(key => key.ToString() ?? string.Empty)
            .Any(key => key.Contains("INSTANA", StringComparison.OrdinalIgnoreCase) ||
                        key.Contains("PROFILER", StringComparison.OrdinalIgnoreCase));
}

