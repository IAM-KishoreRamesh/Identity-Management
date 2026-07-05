<#
.SYNOPSIS
    Provisions a Connected Organization in Entra ID (Entitlement Management).

.DESCRIPTION
    This script automates the creation of a Connected Organization, which is used in 
    Azure AD Entitlement Management to manage access for external users from specific domains.

.NOTES
    File Name: Day-08-Connected-Organization.ps1
    Permissions Required: EntitlementManagement.ReadWrite.All
#>

try {
    # Check for an active Microsoft Graph session to ensure connectivity
    $mgContext = Get-MgContext -ErrorAction SilentlyContinue
    
    if (-not $mgContext) {
        Write-Host "No active Graph session found. Connecting..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All"
    } else {
        Write-Host "Using existing Graph session: $($mgContext.Account)" -ForegroundColor Cyan
    }
} catch {
    Write-Error "Authentication Initialization Failed. `nDetails: $($_.Exception.Message)"
    return
}

Write-Host "Provisioning Connected Organization in Entra ID..." -ForegroundColor Cyan

# 1. DEFINE CONFIGURATION #########################################################################
# Define the connected organization details using a hash table for the -BodyParameter
$ConnectedOrgParam = @{
    DisplayName     = "Fabrikam"
    Description     = "Connected Organization for Fabrikam"
    
    # NOTE: While 'State' may appear optional or defaulted in the Azure Portal GUI, 
    # it is MANDATORY for Microsoft Graph API requests. 
    # Valid values: 'configured' (Active) or 'proposed' (Draft).
    State           = "configured" 

    IdentitySources = @(
        @{
            # NOTE: The API requires the @odata.type property to identify the source type.
            # In the GUI, this is handled via a dropdown. 
            # For verified domains, use: #microsoft.graph.domainIdentitySource
            # For other Entra tenants, use: #microsoft.graph.azureActiveDirectoryTenant
            "@odata.type" = "#microsoft.graph.domainIdentitySource"
            DisplayName   = "Fabrikam" 
            
            DomainName    = "fabrikam.com" # Exact match required; wildcards are not supported here.
        }
    )
}

# 2. EXECUTE PROVISIONING #########################################################################
try {
    # Create the connected organization using the Microsoft Graph SDK
    $ConnectOrgParam = New-MgEntitlementManagementConnectedOrganization -BodyParameter $ConnectedOrgParam -ErrorAction Stop
    Write-Host "SUCCESS: Connected Organization provisioned -> $($ConnectOrgParam.Id)" -ForegroundColor Green
}
catch{
    Write-Host "FAILED to create Connected Organization: $($_.Exception.Message)" -ForegroundColor Red
}