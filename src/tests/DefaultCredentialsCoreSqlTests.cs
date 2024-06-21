using System.Data.Common;
using Azure.Data.Tables;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
using NUnit.Framework;

namespace Tests;

[TestFixture, CoreSqlOnly]
public class DefaultCredentialsCoreSqlTests
{
    [Test]
    public async Task Should_establish_database_connection()
    {
        var builder = new DbConnectionStringBuilder
        {
            ConnectionString = Environment.GetEnvironmentVariable("CosmosConnectionString")!
        };
        builder.TryGetValue("AccountEndpoint", out var accountEndpoint);

        var cosmosClient = new CosmosClient($"{accountEndpoint}", new DefaultAzureCredential(), new CosmosClientOptions());

        // with RBAC data plane operations are not supported, so we are using the existing database and container
        var database = cosmosClient.GetDatabase(Environment.GetEnvironmentVariable("CosmosConnectionString_DatabaseName"));
        var container = database.GetContainer(Environment.GetEnvironmentVariable("CosmosConnectionString_ContainerOrTableName"));
        var response = await container.CreateItemAsync(new Customer { id = Guid.NewGuid().ToString(), Name = "John Doe" });

        Assert.That(response.StatusCode, Is.InRange(200, 299));
    }

    class Customer
    {
        public string id { get; set; }
        public string Name { get; set; }
    }
}