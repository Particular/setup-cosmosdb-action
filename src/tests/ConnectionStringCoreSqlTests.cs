using Microsoft.Azure.Cosmos;
using NUnit.Framework;

namespace Tests;

[TestFixture]
public class ConnectionStringCoreSqlTests
{
    [SetUp]
    public void Setup()
    {
        if (Environment.GetEnvironmentVariable("CosmosConnectionString_Api") != "CoreSQL")
        {
            Assert.Inconclusive("Skipping test because CosmosConnectionString_Api is not set to 'CoreSQL'");
        }
    }

    [Test]
    public async Task Should_establish_database_connection()
    {
        var cosmosClient = new CosmosClient(Environment.GetEnvironmentVariable("CosmosConnectionString"));
        var response = await cosmosClient.CreateDatabaseIfNotExistsAsync("testdb");
        Assert.That(response.StatusCode, Is.InRange(200, 299));
    }
}