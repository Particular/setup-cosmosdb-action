param (
    [string]$cosmosName,
    [string]$azureCredentials
)

$resourceGroup = $Env:RESOURCE_GROUP_OVERRIDE ?? "GitHubActions-RG"

$ignore = az cosmosdb delete --resource-group $resourceGroup --name $cosmosName --yes --no-wait
