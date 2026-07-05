<#
.SYNOPSIS
    Deploys the Telemetry Log Analytics Workspace using Bicep.

.DESCRIPTION
    This script creates a target Resource Group if it doesn't exist and 
    deploys the Bicep template located in the same directory.
#>

$ResourceGroupName = "rg-telemetry-prod-001"
$Location = "centralindia"
$TemplateFile = "d:\Azure\Azure Governance Framework\Identity-Management\Day-06-Telemetry.bicep"

# 1. Check for Azure Connection (Login if necessary)
if (-not (Get-AzContext)) {
    Write-Host "No Azure context found. Please log in..." -ForegroundColor Yellow
    Connect-AzAccount
}

# 2. Ensure Bicep CLI is installed
try {
    Write-Host "Checking for Bicep CLI..." -ForegroundColor Cyan
    $null = Get-AzBicepVersion
} catch {
    Write-Host "Bicep CLI not found. Installing now..." -ForegroundColor Yellow
    Install-AzBicep
}

# 3. Create the Resource Group
$existingRg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if ($null -eq $existingRg) {
    Write-Host "Resource Group '$ResourceGroupName' not found. Creating it in $Location..." -ForegroundColor Yellow
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag @{Project="Telemetry"; Environment="Prod"}
} else {
    Write-Host "Resource Group '$ResourceGroupName' already exists. Skipping creation." -ForegroundColor Gray
}

# 4. Deploy the Bicep Template
Write-Host "Deploying Bicep template: $TemplateFile" -ForegroundColor Cyan
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -Verbose
