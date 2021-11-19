param (
    [string]$cosmosName,
    [SecureString]$azureCredentials
)

# Use this once cosmosdb delete offers --no-wait argument, until then, it takes too long (~7m) and we use curl instead
#$ignore = az cosmosdb delete --resource-group GitHubActions-RG --name $cosmosName --yes

# curl-based method
$credentials = $azureCredentials | ConvertFrom-Json
$token = curl -X POST -d "grant_type=client_credentials&client_id=$($credentials.clientId)&client_secret=$($credentials.clientSecret)&resource=https%3A%2F%2Fmanagement.azure.com%2F" https://login.microsoftonline.com/$($credentials.tenantId)/oauth2/token | ConvertFrom-Json
$authHeader = "Authorization: Bearer $($token.access_token)"
$resourceUrl = "https://management.azure.com/subscriptions/$($credentials.subscriptionId)/resourceGroups/GitHubActions-RG/providers/Microsoft.DocumentDB/databaseAccounts/$($cosmosName)?api-version=2021-04-15"
curl -X DELETE $resourceUrl -H $authHeader -H "Content-Type: application/json" --silent
