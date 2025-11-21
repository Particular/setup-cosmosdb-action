param (
    [string]$cosmosName,
    [string]$connectionStringName,
    [string]$tagName,
    [string]$api,
    [string]$azureCredentials
)

$credentials = $azureCredentials | ConvertFrom-Json

$resourceGroup = $Env:RESOURCE_GROUP_OVERRIDE ?? "GitHubActions-RG"

if ($Env:REGION_OVERRIDE) {
  $region = $Env:REGION_OVERRIDE
}
else { 
  echo "Getting the Azure region in which this workflow is running..."
  $hostInfo = curl --silent -H Metadata:true "169.254.169.254/metadata/instance?api-version=2017-08-01" | ConvertFrom-Json
  $region = $hostInfo.compute.location
  echo "Actions agent running in Azure region $region"
}

function Get-NearbyRegions {
  param([string]$primary)

  $p = ($primary ?? "").ToLower()

  # West → central family → east
  if ($p -match '^westus(\d+)?$') {
    $siblings = @("westus","westus2","westus3","westcentralus")
    $nearby   = @("southcentralus","centralus","northcentralus")
    $others   = @("eastus2","eastus")
    return @($primary) + $siblings + $nearby + $others
  }

  # East → central family → west
  if ($p -match '^eastus(\d+)?$') {
    $siblings = @("eastus","eastus2")
    $nearby   = @("centralus","northcentralus","southcentralus")
    $others   = @("westus","westus2","westus3","westcentralus")
    return @($primary) + $siblings + $nearby + $others
  }

  switch -Regex ($p) {
    # Central US (Iowa): central siblings → east → west
    '^centralus$' {
      return @($primary,"northcentralus","southcentralus","eastus","eastus2","westus","westus2","westus3","westcentralus")
    }
    # North Central (Illinois): central siblings → east → west
    '^northcentralus$' {
      return @($primary,"centralus","southcentralus","eastus","eastus2","westus","westus2","westus3","westcentralus")
    }
    # South Central (Texas): central siblings → west → east
    '^southcentralus$' {
      return @($primary,"centralus","northcentralus","westus","westus2","westus3","westcentralus","eastus","eastus2")
    }
    # West Central (Utah): west siblings → central family → east
    '^westcentralus$' {
      return @($primary,"westus","westus2","westus3","southcentralus","centralus","northcentralus","eastus2","eastus")
    }
  }

  # Generic fallback: central family → east → west
  return @(
    $primary,
    "centralus","northcentralus","southcentralus",
    "eastus2","eastus",
    "westus2","westus","westus3","westcentralus"
  )
}

# Pull physical regions, and constrain to the US so we don't jump continents.
$usRegions = az account list-locations --query "[?metadata.regionType=='Physical' && contains(regionalDisplayName, '(US)')].name" -o tsv

# Build ordered list: detected region + nearby list, filtered to what actually exists + unique.
$orderedRegions = Get-NearbyRegions -primary $region |
  Where-Object { $_ -and ($usRegions -contains $_.ToLower()) } |
  Select-Object -Unique

$packageTag   = "Package=$tagName"
$runnerOsTag  = "RunnerOS=$($Env:RUNNER_OS)"
$dateTag      = "Created=$(Get-Date -Format 'yyyy-MM-dd')"
$capabilities = if ($api -eq "Table") { "EnableTable" } else { "EnableServerless" }

$acctDetails  = $null
$chosenRegion = $null

foreach ($tryRegion in $orderedRegions) {
  echo "Creating CosmosDB database account $cosmosName in $tryRegion (This can take awhile.)"

  $out  = az cosmosdb create `
            --name $cosmosName `
            --location regionName=$tryRegion failoverPriority=0 isZoneRedundant=False `
            --resource-group $resourceGroup `
            --capabilities $capabilities `
            --tags $packageTag $runnerOsTag $dateTag `
            --output json 2>&1
  $code = $LASTEXITCODE

  if ($code -eq 0) {
    try {
      $acctDetails = $out | ConvertFrom-Json
      $chosenRegion = $tryRegion
      echo "Cosmos account created in region: $chosenRegion"
      break
    } catch {
      echo "Failed to parse JSON from az output:"
      echo $out
      echo "Non-JSON success output; aborting fallback."
      break
    }
  } else {
    echo $out

    if ($out -match 'ServiceUnavailable|high demand|quota|capacity|zonal redundant|Availability Zones') {
      echo "Creation in $tryRegion failed due to capacity; trying next preferred region after cleaning up the database in the failed provisioning state (This can take awhile)..."
      # We can't use --no-await here because we need to make sure the previous instance is gone.
      az cosmosdb delete --resource-group $resourceGroup --name $cosmosName --yes
      continue
    } else {
      echo "Creation in $tryRegion failed due to a non-capacity error; not attempting other regions."
      break
    }
  }
}

if (-not $acctDetails) {
  echo "Account creation failed. Last error shown above."
  echo "If Azure is reporting demand too high for your region(s), consider requesting access: https://aka.ms/cosmosdbquota"
  exit 1
}

if ($api -eq "Sql") {
  $databaseName = "CosmosDBPersistence"
  $containerName = "CosmosDBPersistenceContainer"
  echo "Creating CosmosDB SQL Database "
  $dbDetails = az cosmosdb sql database create --name $databaseName --account-name $cosmosName --resource-group $resourceGroup | ConvertFrom-Json
  echo "Creating CosmosDB SQL Database Container"
  $containerDetails = az cosmosdb sql container create --resource-group $resourceGroup --account-name $cosmosName --database-name $databaseName --name $containerName --partition-key-path "/id"
  echo "Assigning Cosmos DB Built-in Data Contributor"
  $roleAssignmentDetails = az cosmosdb sql role assignment create --account-name $cosmosName --resource-group $resourceGroup --role-assignment-id 00000000-0000-0000-0000-000000000002 --scope $acctDetails.id --principal-id $credentials.principalId --role-definition-name "Cosmos DB Built-in Data Contributor"
}

if ($api -eq "Table") {
  $databaseName = "TablesDB"
  $containerName = $databaseName

  echo "Creating CosmosDB Table API Table"
  $null = az cosmosdb table create `
            --account-name $cosmosName `
            --resource-group $resourceGroup `
            --name $databaseName `
            -o none

  echo "Waiting for Cosmos Table data plane readiness and table visibility..."
  # Yes this is a hardcoded value, we tried a few things but more sophisticated approaches still failed
  Start-Sleep -Seconds 180
}

echo "Getting CosmosDB access keys"
$keyDetails = az cosmosdb keys list --name $cosmosName --resource-group $resourceGroup --type connection-strings | ConvertFrom-Json
$cosmosConnectString = $($keyDetails.connectionStrings | Where-Object { $_.keyKind -eq 'Primary' -and $_.type -eq $api }).connectionString
echo "::add-mask::$cosmosConnectString"
echo "$connectionStringName=$cosmosConnectString" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf-8 -Append

$apiFlavour = "$($connectionStringName)_Api"
echo "$apiFlavour=$api" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf-8 -Append

$databaseNameEnvName = "$($connectionStringName)_DatabaseName"
echo "$databaseNameEnvName=$databaseName" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf-8 -Append

$containerNameEnvName = "$($connectionStringName)_ContainerOrTableName"
echo "$containerNameEnvName=$containerName" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf-8 -Append
