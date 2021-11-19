param (
    [string]$cosmosName,
    [string]$connectionStringName,
    [string]$tagName
)

echo "Cloning 'config' branch to determine currently-allowed Azure regions..."
$configDir = ".ci-config/$cosmosName"
$configPath = ".ci-config/$cosmosName/azure-regions.config"
git clone --branch config https://github.com/Particular/setup-cosmosdb-action $configDir

$allowedRegions = Get-Content ./.ci-config/azure-regions.config | Where-Object { $_.trim() -ne '' -And !$_.startsWith('#') }
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
echo "Creating CosmosDB database account $cosmosName (This can take awhile.)"
$acctDetails = az cosmosdb create --name $cosmosName --location regionName=$region failoverPriority=0 isZoneRedundant=False --resource-group GitHubActions-RG --capabilities EnableServerless --tags $packageTag $runnerOsTag $dateTag | ConvertFrom-Json

if(!$acctDetails || !$acctDetails.documentEndpoint)
{
  echo "Account creation failed. $acctDetails"
  echo "If Azure is reporting demand too high for this region, refer to documentation for COSMOS_ALLOWED_REGIONS secret and consider updating."
  exit 1;
}

$documentEndpoint = $acctDetails.documentEndpoint
echo "::add-mask::$documentEndpoint"

echo "Getting CosmosDB access keys"
$keyDetails = az cosmosdb keys list --name $cosmosName --resource-group GitHubActions-RG | ConvertFrom-Json
$cosmosKey = $keyDetails.primaryMasterKey
echo "::add-mask::$cosmosKey"

echo "Creating CosmosDB SQL Database "
$dbDetails = az cosmosdb sql database create --name CosmosDBPersistence --account-name $cosmosName --resource-group GitHubActions-RG | ConvertFrom-Json

echo "$connectionStringName=AccountEndpoint=$($documentEndpoint);AccountKey=$($cosmosKey);" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf-8 -Append