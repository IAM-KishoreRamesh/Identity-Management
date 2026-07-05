> **[SANITIZED ON 2026-07-05] SECURITY AUDIT:** Hardcoded tenant IDs, credentials, and user emails within this log have been replaced with generic placeholders for public release.

# Technical Runbook: Day 16 - Enterprise Applications & SSO Baseline

**Execution Date:** May 25, 2026
**Target Environment:** Microsoft Entra ID
**Objective:** Establish a centralized Single Sign-On (SSO) baseline for a mock third-party SaaS application. Enforce a Zero-Trust perimeter by disabling default tenant-wide access and automate identity lifecycle provisioning by binding the application to Entitlement Management.

## 1. Architectural Overview

By default, Microsoft Entra ID permits any authenticated user in the tenant to attempt login to a newly registered Enterprise Application. This represents a massive internal attack surface. This deployment modifies the default behavior, mandating explicit administrative or programmatic assignment before an identity can interact with the application logic.

## 2. Phase 1: Infrastructure as Code (IaC) Provisioning

**Objective:** Programmatically register the application, instantiate the Service Principal, and secure the access baseline using the Microsoft Graph API.

### 2.1 Dependency & Authentication

```powershell
Disconnect-MgGraph -ErrorAction SilentlyContinue
Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All" -TenantId "<YOUR_TENANT_NAME>.onmicrosoft.com"

```

### 2.2 The Provisioning Payload

```powershell
Write-Host "Initiating Enterprise Application Provisioning..." -ForegroundColor Cyan

# 1. Identity Registration
$AppParams = @{
    displayName = "Project Alpha SaaS Dashboard"
    signInAudience = "AzureADMyOrg"
}
$App = New-MgApplication -BodyParameter $AppParams
Write-Host "Application Registration Created: $($App.AppId)" -ForegroundColor Yellow

# 2. Service Principal Instantiation
$SPParams = @{
    appId = $App.AppId
}
$SP = New-MgServicePrincipal -BodyParameter $SPParams
Write-Host "Service Principal Created: $($SP.Id)" -ForegroundColor Yellow

```

### 2.3 Architectural Friction: Boolean Parsing Bug

During execution, the standard `Update-MgServicePrincipal -AppRoleAssignmentRequired $true` cmdlet failed due to a known Graph API parameter binding exception (`A positional parameter cannot be found that accepts argument 'True'`).

**The Engineered Fix:**
To bypass the PowerShell syntax limitation, the configuration was injected directly via a JSON hash table payload targeting the specific Service Principal ID.

```powershell
Write-Host "Patching existing Service Principal..." -ForegroundColor Cyan

$UpdateParams = @{
    appRoleAssignmentRequired = $true
}

Update-MgServicePrincipal -ServicePrincipalId $SP.Id -BodyParameter $UpdateParams

Write-Host "SUCCESS: Application is now strictly locked down." -ForegroundColor Green

```

## 3. Phase 2: Lifecycle Automation (Entitlement Management)

**Objective:** Bind the secured application to the existing Identity Governance framework so that access is granted purely through approved Access Packages, eliminating manual IT ticketing.

### 3.1 Overcoming API Replication Lag

Immediately following IaC deployment, the Entra ID GUI text-search index failed to display the application. To bypass this replication lag, the exact **Application ID** (`c1edd799-8fc6-4507-8faa-d6a29297ec69`) was utilized to force direct database resolution.

### 3.2 Catalog & Package Binding

1. **Catalog Addition:** Bound `Project Alpha SaaS Dashboard` to the **Engineering Project Resource** catalog.
2. **Access Package Assignment:** Assigned the application to the **Engineering Project Access** package with the **Default Access** role.
3. **Result:** Any user successfully navigating the approval workflow for this Access Package is automatically provisioned SSO access to the dashboard.

## 4. Phase 3: Boundary Verification

Configuration is invalid without objective verification of the user experience.

* **Test Vector:** An isolated Incognito browser session.
* **Test Identity:** Standard Engineering User (`A.rajavel`).
* **Condition:** The user had *not* requested or been granted the Engineering Access Package.
* **Execution:** Navigated to `myapps.microsoft.com`.
* **Result:** The `Project Alpha SaaS Dashboard` was completely absent from the user's portal.
* **Conclusion:** The `AppRoleAssignmentRequired = $true` enforcement is operational. The Zero-Trust perimeter holds.

---
