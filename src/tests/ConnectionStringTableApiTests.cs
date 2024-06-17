using Azure.Data.Tables;
using NUnit.Framework;

namespace Tests;

[TestFixture]
public class ConnectionStringTableApiTests
{
    [SetUp]
    public void Setup()
    {
        if (Environment.GetEnvironmentVariable("CosmosConnectionString_Api") != "Table")
        {
            Assert.Inconclusive("Skipping test because CosmosConnectionString_Api is not set to 'Table'");
        }
    }

    [Test]
    public async Task Should_establish_table_connection()
    {
        var tableServiceClient = new TableServiceClient(Environment.GetEnvironmentVariable("CosmosConnectionString"));
        var tableClient = tableServiceClient.GetTableClient("testtable");
        var response = await tableClient.CreateIfNotExistsAsync();
        Assert.That(response.HasValue, Is.True);
    }
}