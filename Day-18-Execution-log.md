> **[SANITIZED ON 2026-07-05] SECURITY AUDIT:** Hardcoded tenant IDs, credentials, and user emails within this log have been replaced with generic placeholders for public release.

# Technical Runbook: Day 18 - Workload Identity Least Privilege Scoping

**Objective:** Transition the Day 17 headless Workload Identity from a state of "Default Deny" to an operational state by programmatically injecting the `User.ReadWrite.All` Application permission via the Microsoft Graph API.

## 1. Architectural Overview

Creating an App Registration and generating a Client Secret (Day 17) only establishes the identity's authentication plane. By default, Microsoft Entra ID assigns zero permissions to new service principals. If an automation script attempts to modify the directory using un-scoped credentials, the Graph API gateway drops the request with a `403 Forbidden` error.

To enable the Phase 2 legacy synchronization pipeline, this deployment enforces the **Principle of Least Privilege**. The workload identity is explicitly denied directory-wide administrative access. Instead, it is granted a single, tightly bounded Application Role (`User.ReadWrite.All`) targeting the Microsoft Graph resource engine. This limits the blast radius exclusively to user identity lifecycles.

## 2. Phase 1: Overcoming API Token Caching Vulnerabilities

During the initial deployment attempt, the Microsoft Graph PowerShell SDK threw a known fatal error: `DeviceCodeCredential authentication failed: Object reference not set to an instance of an object.`

**Root Cause:** When utilizing the `-UseDeviceAuthentication` parameter, the local PowerShell runspace occasionally drops the cached memory reference to the Entra ID access token immediately after connection. Subsequent cmdlets attempt to pass a null token to the Graph API, causing an immediate crash.

**The Engineering Fix:** The script was refactored to purge the corrupted session (`Disconnect-MgGraph`) and bypass the device code flag, forcing a clean, interactive Web Account Manager (WAM) token acquisition.

## 3. Phase 2: Infrastructure as Code (IaC) Deployment

**Prerequisite Session Management:**

```powershell
# Purge stale tokens and force a clean interactive session
Disconnect-MgGraph -ErrorAction SilentlyContinue
Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All" -TenantId "<YOUR_TENANT_NAME>.onmicrosoft.com"

```

**The App-Role Injection Payload:**

```powershell
Write-Host "Initiating Graph API Permission Injection for OIM Sync Engine..." -ForegroundColor Cyan

# 1. Target the Workload Identity
$ClientAppId = "<YOUR_CLIENT_ID>"
$TargetSP = Get-MgServicePrincipal -Filter "AppId eq '$ClientAppId'"

if (-not $TargetSP) { throw "FATAL ERROR: Target Service Principal not found." }

# 2. Locate the First-Party Microsoft Graph Service Principal
# AppId '00000003-0000-0000-c000-000000000000' is the universal immutable identifier for Microsoft Graph
$GraphSP = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
if (-not $GraphSP) { throw "FATAL ERROR: Failed to resolve the Graph resource engine." }

# 3. Extract the specific App Role ID for User.ReadWrite.All
$AppRole = $GraphSP.AppRoles | Where-Object { $_.Value -eq "User.ReadWrite.All" -and $_.AllowedMemberTypes -contains "Application" }
if (-not $AppRole) { throw "FATAL ERROR: Could not locate the 'User.ReadWrite.All' application role definition." }

# 4. Construct and Inject the AppRole Assignment payload
$AssignmentParams = @{
    principalId = $TargetSP.Id          
    resourceId  = $GraphSP.Id           
    appRoleId   = $AppRole.Id           
}

try {
    Write-Host "Injecting role assignment onto Service Principal ID: $($TargetSP.Id)..." -ForegroundColor Yellow
    $Assignment = New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $TargetSP.Id -BodyParameter $AssignmentParams -ErrorAction Stop
    Write-Host "SUCCESS: 'User.ReadWrite.All' application permission successfully assigned." -ForegroundColor Green
} catch {
    Write-Host "CRITICAL FAILURE: Permission assignment failed -> $($_.Exception.Message)" -ForegroundColor Red
}

```

## 4. Operational Boundary Verification

Because the execution context was driven by a Global Administrator session, the required **Admin Consent** for Application permissions was committed synchronously to the backend database.

Physical boundary verification was executed via the Entra admin center (`entra.microsoft.com`):

1. **Routing:** Identity > Applications > App registrations > `OIM-12c-Sync-Engine` > API permissions.
2. **Permission Type Validation:** Confirmed the injected role (`User.ReadWrite.All`) explicitly registered under the **Application** type, proving it operates headlessly without a delegated user context.
3. **Consent Validation:** Confirmed the status indicator displayed the green checkmark mapping to the required **Granted for <YOUR_TENANT_NAME>** terminal state.

**Status:** The machine identity is fully armed and restricted to its designated scope. Day 18 architecture is secure.

---
