param (
    [string]$cosmosName,
    [string]$connectionStringName,
    [string]$tagName,
    [string]$api,
    [string]$azureCredentials
)

$credentials = $azureCredentials | ConvertFrom-Json
$principalId = $credentials.principalId

echo "Cloning 'config' branch to determine currently-allowed Azure regions..."
git clone --branch config https://github.com/Particular/setup-cosmosdb-action .ci-config
[array]$allowedRegions = Get-Content .ci-config/azure-regions.config | Where-Object { $_.trim() -ne '' -And !$_.startsWith('#') }
Remove-Item -Path .ci-config -Recurse -Force

echo "Allowed Regions:"
$allowedRegions | ForEach-Object { echo " * $_" }

echo "Getting the Azure region in which this workflow is running..."
$hostInfo = curl --silent -H Metadata:true "169.254.169.254/metadata/instance?api-version=2017-08-01" | ConvertFrom-Json
$region = $hostInfo.compute.location
echo "Actions agent running in Azure region $region"

if (!$allowedRegions.contains($region))
{
  echo "Region '$region' not currently allowed for Cosmos DB."
  $randomIndex = Get-Random -Minimum 0 -Maximum $allowedRegions.length
  $region = $allowedRegions[$randomIndex]
  echo "Region randomly reset to $region"
}

$packageTag = "Package=$tagName"
$runnerOsTag = "RunnerOS=$($Env:RUNNER_OS)"
$dateTag = "Created=$(Get-Date -Format "yyyy-MM-dd")"
$capabilities = If ($api -eq "Table") { "EnableTable" } Else { "EnableServerless" }
echo "Creating CosmosDB database account $cosmosName (This can take awhile.)"
$acctDetails = az cosmosdb create --name $cosmosName --location regionName=$region failoverPriority=0 isZoneRedundant=False --resource-group GitHubActions-RG --capabilities $capabilities --tags $packageTag $runnerOsTag $dateTag | ConvertFrom-Json

if (!$acctDetails)
{
  echo "Account creation failed. $acctDetails"
  echo "If Azure is reporting demand too high for this region, update https://github.com/Particular/setup-cosmosdb-action/blob/config/azure-regions.config"
  exit 1;
}

if ($api -eq "Sql") {
  echo "Creating CosmosDB SQL Database "
  $dbDetails = az cosmosdb sql database create --name CosmosDBPersistence --account-name $cosmosName --resource-group GitHubActions-RG | ConvertFrom-Json
  echo "Creating CosmosDB SQL Database Container"
  $containerDetails = az cosmosdb sql container create --resource-group GitHubActions-RG --account-name $cosmosName --database-name CosmosDBPersistence --name CosmosDBPersistenceContainer --partition-key-path "/id"
  echo "Assigning Cosmos DB Built-in Data Contributor"
  $roleAssignmentDetails = az cosmosdb sql role assignment create --account-name $cosmosName --resource-group GitHubActions-RG --role-assignment-id 00000000-0000-0000-0000-000000000002 --scope "/" --principal-id $principalId --role-definition-name "Cosmos DB Built-in Data Contributor"
}

if ($api -eq "Table") {
  echo "Creating CosmosDB Table API Table"
  $tblDetails = az cosmosdb table create --account-name $cosmosname --resource-group GitHubActions-RG --name TablesDB | ConvertFrom-JSON
}

echo "Getting CosmosDB access keys"
$keyDetails = az cosmosdb keys list --name $cosmosname --resource-group GitHubActions-RG --type connection-strings | ConvertFrom-Json
$cosmosConnectString = $($keyDetails.connectionStrings | Where-Object { $_.keyKind -eq 'Primary' -and $_.type -eq $api }).connectionString
echo "::add-mask::$cosmosConnectString"
echo "$connectionStringName=$cosmosConnectString" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf-8 -Append

$apiFlavour = "$($connectionStringName)_Api"
echo "$apiFlavour=$api" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf-8 -Append