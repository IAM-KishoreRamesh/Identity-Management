<#
.SYNOPSIS
    Configures Entra ID Entitlement Management resources.

.DESCRIPTION
    This script automates the creation of an Entitlement Management Catalog, a Security Group, 
    and an Access Package. It handles authentication checks and uses the Microsoft Graph SDK.

.NOTES
    File Name: Day-07-Entitlement-v2.ps1
    Permissions Required: EntitlementManagement.ReadWrite.All, Group.ReadWrite.All
#>

try {
    # Rely on native PowerShell auto-loading. Do not force explicit imports.
    $mgContext = Get-MgContext -ErrorAction SilentlyContinue
    
    if (-not $mgContext) {
        Write-Host "No active Graph session found. Connecting..." -ForegroundColor Cyan
        # Connect-MgGraph will auto-load Microsoft.Graph.Authentication
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All", "Group.ReadWrite.All"
    } else {
        Write-Host "Using existing Graph session: $($mgContext.Account)" -ForegroundColor Cyan
    }
} catch {
    Write-Error "Authentication Initialization Failed. `nDetails: $($_.Exception.Message)"
    return
}

# 1. CREATE THE CATALOG ###########################################################################
$CatalogParam = @{
    DisplayName = "Engineering Project Resource" 
    Description = "Self-Service catalog for Engineering"
}

try {
    $newCatalog = New-MgEntitlementManagementCatalog @CatalogParam -ErrorAction Stop
    Write-Host "Catalog created successfully. ID: $($newCatalog.Id)" -ForegroundColor Green
} catch {
    Write-Error "Failed to create Catalog: $($_.Exception.Message)"
    return
}

# 2. CREATE THE SECURITY GROUP ####################################################################
$GroupParam = @{
    DisplayName     = "SG-Project-Contributors"
    MailEnabled     = $false
    SecurityEnabled = $true
    MailNickname    = "sg-project"
}

try {
    # This cmdlet will auto-load Microsoft.Graph.Groups
    $newGroup = New-MgGroup @GroupParam -ErrorAction Stop
    Write-Host "Group created successfully. ID: $($newGroup.Id)" -ForegroundColor Green
} catch {
    Write-Error "Failed to create Group: $($_.Exception.Message)"
    return
}

# 3. CREATE THE ACCESS PACKAGE ####################################################################
$PackageParam = @{
    displayName = "Engineering Project Access"
    description = "Grants security reader role to Engineering Project Contributors."
    isHidden    = $false
    catalog     = @{
        id = $newCatalog.Id
    }
}

try {
    $newPackage = New-MgEntitlementManagementAccessPackage -BodyParameter $PackageParam -ErrorAction Stop
    Write-Host "Access package created successfully. ID: $($newPackage.Id)" -ForegroundColor Green
} catch {
    Write-Error "Failed to create Access Package: $($_.Exception.Message)"
}