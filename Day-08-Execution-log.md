# Identity Governance Runbook: Day 08

**Objective:** Lifecycle Management & B2B Sprawl Control
**Target State:** Eliminate standing privileges for external contractors by establishing a cryptographically bounded Connected Organization and enforcing an automated 30-day access kill-switch.

## Phase 1: Provisioning the Connected Organization (IaC)

To prevent rogue guest invitations and enforce a zero-trust boundary, a Connected Organization was provisioned using Microsoft Graph PowerShell. This ensures Entra ID legally recognizes the `fabrikam.com` domain as a trusted vendor network.

### Execution Script

```powershell
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

```

### Challenges Encountered & Engineering Resolutions

1. **GUI vs. API Discrepancies:** Attempting to search for the human-readable string "Fabrikam" in the Entra GUI failed. *Resolution:* The identity boundary relies on DNS domains, not display names. The system strictly requires the domain format (`fabrikam.com`) to establish the identity source.
2. **PowerShell Parser Errors (Splatting):** Splatting failed initially due to the `@odata.type` key. *Resolution:* In PowerShell hash tables, keys containing special characters (like `@` or `-`) must be strictly enclosed in quotation marks, otherwise, the interpreter evaluates them as illegal operators.
3. **Graph API Schema Strictness:** The API rejected multiple payload iterations with `400 Bad Request` and missing information errors. *Resolution:* Identified that the Graph API enforces rigid case-sensitivity and exact schema mapping. `identitySources` must be pluralized in the parameter key, while the value must map to the singular `#microsoft.graph.domainIdentitySource`. Furthermore, omitting the mandatory `state` parameter results in immediate payload rejection.

---

## Phase 2: Lifecycle Policy Configuration

With the vendor boundary established, a new policy was bound to the "Engineering Project Access" package to automate contractor offboarding.

### Execution Steps

1. Navigated to **Entitlement management** > **Access packages** > **Engineering Project Access** > **Policies**.
2. Created a new policy targeting **"For users not in your directory"**.
3. Restricted access specifically to the **Fabrikam** Connected Organization.
4. Configured the **Lifecycle** rules to enforce an immutable expiration of **30 days** with no capability for the user to request custom timelines.

### Challenges Encountered & Engineering Resolutions

1. **Inheritance Lockout:** The option to select "For users not in your directory" was permanently greyed out at the Access Package level. *Resolution:* Identified a parent-child inheritance conflict. Access Packages inherit boundaries from their parent Catalog. The parent Catalog's properties had to be explicitly updated to "Enable for external users" before the child package was legally allowed to grant external access.

---

## Phase 3: Boundary Verification (Edge Testing)

To mathematically prove the architecture, an adversarial access attempt was executed against the hidden My Access portal URL.

### Execution & Results

* **Test Vector:** Accessed the request URL via an isolated browser instance using a rogue consumer identity (`xyz@gmail.com`).
* **Expected Result:** Immediate authorization block.
* **Actual Result:** **Success**. The Entra ID engine intercepted the request, evaluated the incoming domain against the approved Connected Organization identity sources, and dropped the connection at the edge. The system refused to issue an authentication code, proving the zero-trust B2B boundary is fully operational.