using Azure.Data.Tables;
using NUnit.Framework;

namespace Tests;

[TestFixture, TableApiOnly]
public class ConnectionStringTableApiTests
{
    [Test]
    public async Task Should_establish_table_connection()
    {
        var tableServiceClient = new TableServiceClient(Environment.GetEnvironmentVariable("CosmosConnectionString"));
        var tableClient = tableServiceClient.GetTableClient("testtable");
        var response = await tableClient.CreateIfNotExistsAsync();

        Assert.That(response.GetRawResponse().Status, Is.InRange(200, 299));
    }
}