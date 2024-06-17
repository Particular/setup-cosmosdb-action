using Microsoft.Azure.Cosmos;
using NUnit.Framework;

namespace Tests;

[TestFixture, CoreSqlOnly]
public class ConnectionStringCoreSqlTests
{
    [Test]
    public async Task Should_establish_database_connection()
    {
        var cosmosClient = new CosmosClient(Environment.GetEnvironmentVariable("CosmosConnectionString"));
        var response = await cosmosClient.CreateDatabaseIfNotExistsAsync("testdb");
        Assert.That(response.StatusCode, Is.InRange(200, 299));
    }
}