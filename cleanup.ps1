param (
    [string]$cosmosName,
    [string]$azureCredentials
)

$resourceGroup = $Env:RESOURCE_GROUP_OVERRIDE ?? "GitHubActions-RG"

# Use this once cosmosdb delete offers --no-wait argument, until then, it takes too long (~7m) and we use curl instead
#$ignore = az cosmosdb delete --resource-group GitHubActions-RG --name $cosmosName --yes

# az rest method
$credentials = $azureCredentials | ConvertFrom-Json
$subscriptionId = $credentials.subscriptionId
az rest --method DELETE `
     --uri https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$($resourceGroup)/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosName}?api-version=2021-04-15
