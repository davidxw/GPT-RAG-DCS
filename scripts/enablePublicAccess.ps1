param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup
)

$ErrorActionPreference = "Stop"

Write-Host "Checking resource group '$ResourceGroup'..."

# --- Storage Accounts ---
Write-Host "`nLooking for Storage Accounts..."
$storageAccounts = az storage account list --resource-group $ResourceGroup --query "[].name" -o tsv

if ($storageAccounts) {
    foreach ($account in $storageAccounts) {
        Write-Host "  Enabling public network access for Storage Account: $account"
        az storage account update --resource-group $ResourceGroup --name $account --public-network-access Enabled --output none
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  Failed to update Storage Account: $account"
        } else {
            Write-Host "  Successfully updated Storage Account: $account"
        }
    }
} else {
    Write-Host "  No Storage Accounts found."
}

# --- Cosmos DB Accounts ---
Write-Host "`nLooking for Cosmos DB Accounts..."
$cosmosAccounts = az cosmosdb list --resource-group $ResourceGroup --query "[].name" -o tsv

if ($cosmosAccounts) {
    foreach ($account in $cosmosAccounts) {
        Write-Host "  Enabling public network access for Cosmos DB Account: $account"
        az cosmosdb update --resource-group $ResourceGroup --name $account --public-network-access ENABLED --output none
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  Failed to update Cosmos DB Account: $account"
        } else {
            Write-Host "  Successfully updated Cosmos DB Account: $account"
        }
    }
} else {
    Write-Host "  No Cosmos DB Accounts found."
}

Write-Host "`nDone."
