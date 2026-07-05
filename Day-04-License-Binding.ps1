<#
.SYNOPSIS
    Assigns a specific license SKU to multiple Microsoft Entra ID groups.

.DESCRIPTION
    This script automates Group-Based Licensing (GBL) by iterating through a list of 
    group names and assigning a specified SkuId. It uses the Microsoft Graph PowerShell SDK.

.NOTES
    Requires: Microsoft.Graph.Groups module
    Permissions: Group.ReadWrite.All
#>

# 1. Define License Configuration
# The SkuId represents the specific product (e.g., Microsoft 365 E5).
$TargetSkuId = "84a661c4-e949-4bd2-a560-ed7766fcaf2b" # The skuId or GUID for Microsoft Entra ID P2
$GroupNames = @("SG-Engineering-Users", "SG-HR-Users", "SG-ITSupport-Users")

# 2. Iterate and Assign Licenses
foreach ($GroupName in $GroupNames) {
    # Retrieve group details to obtain the GroupId required for license assignment
    $Group = Get-MgGroup -Filter "DisplayName eq '$GroupName'" -ErrorAction SilentlyContinue
    
    # Construct the license object for the BodyParameter
    $LicenseAdd = @{
        AddLicenses = @(
            @{ SkuId = $TargetSkuId }
        )
        # RemoveLicenses must be provided as an empty array if no licenses are being removed
        RemoveLicenses = @()
    }

    try {
        # Validation to ensure the group was found before proceeding
        if (-not $Group) { throw "Group '$GroupName' not found in Entra ID." }

        # Apply the license to the group via Microsoft Graph
        Set-MgGroupLicense -GroupId $Group.Id -BodyParameter $LicenseAdd -ErrorAction Stop
        Write-Host "SUCCESS: License bound to $GroupName" -ForegroundColor Green
    } catch {
        Write-Host "FAILED: $GroupName -> $($_.Exception.Message)" -ForegroundColor Red
    }
}
