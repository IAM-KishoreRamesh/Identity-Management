# Day 15 Execution Log: Privileged Access Groups (PIM for Groups)

## Architectural Objective

Eliminate standing privileges on the data plane. Standard Azure AD Security Groups grant permanent access, creating an unacceptable blast radius if an identity is compromised. The objective is to transform an **Assigned Security Group** into a **Privileged Access Group** managed by the Privileged Identity Management (PIM) engine, enforcing a zero-trust, time-bound, and audited access model.

## Target Environment

* **Target Group:** `SG-Project-Contributors`
* **Group Type Requirement:** Security Group, Membership Type: **Assigned** (Dynamic groups are incompatible with PIM for Groups eligibility injection).
* **Target Identity:** `A.rajavel` (Standard Engineering User)
* **Eligibility Lifecycle:** 180 Days (P180D)
* **Activation Maximum:** 8 Hours

---

## Phase 1: Control Plane Initialization (Manual Discovery)

*Microsoft Graph Beta endpoints for group onboarding are highly unstable. Initialization must be executed manually to guarantee backend registration.*

1. Navigate to **Entra admin center > Identity Governance > Privileged Identity Management > Groups**.
2. Select **Discover groups**.
3. Locate `SG-Project-Contributors`.
4. Execute **Manage groups** to formally register the object with the PIM engine.
5. **Verification:** The group must be visible in the primary PIM Groups dashboard. Do not check the "Roles and administrators" blade, as that manages directory roles for the group itself, not membership access.

---

## Phase 2: Graph API Infrastructure as Code (IaC) Injection

### 2.1 Dependency Management

The standard Microsoft Graph module does not contain the necessary Identity Governance cmdlets.

```powershell
# Mandatory Module Installation
Install-Module Microsoft.Graph.Identity.Governance -Scope CurrentUser
Import-Module Microsoft.Graph.Identity.Governance

```

### 2.2 Elevated Authentication Context

Standard directory read permissions are insufficient for PIM modifications. The session must be authenticated against the Privileged Access endpoints.

```powershell
Disconnect-MgGraph -ErrorAction SilentlyContinue

# PrivilegedAccess.ReadWrite.AzureADGroup: Essential for JIT payload injection.
# Group.Read.All: Required for target object resolution.
# User.Read.All: Required for identity resolution.
Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All", "PrivilegedAccess.ReadWrite.AzureADGroup" -TenantID "<your-tenant>.onmicrosoft.com"

```

### 2.3 The Deployment Script

This script targets the standard user, constructs the JIT eligibility payload, and executes the administrative assignment via the Identity Governance endpoints.

```powershell
<#
    .SYNOPSIS
        Transforms an Assigned Azure AD Security Group into a PIM-Managed Privileged Access Group and provisions Eligible JIT access.
#>

Write-Host "Initiating PIM for Groups Injection..." -ForegroundColor Cyan

# 1. Acquire Targets
$GroupName = "SG-Project-Contributors"
$TargetUPN = "A.rajavel@<your-tenant>.onmicrosoft.com"

$Group = Get-MgGroup -Filter "DisplayName eq '$GroupName'"
$User = Get-MgUser -UserId $TargetUPN

if (-not $Group -or -not $User) {
    Write-Host "FATAL: Target Group or User not found." -ForegroundColor Red
    return
}

# 2. Construct Eligibility Payload
$PimGroupParams = @{
    accessId = "member" 
    principalId = $User.Id 
    groupId = $Group.Id 
    action = "AdminAssign" 
    justification = "SC-300: Verified JIT access for data plane security." 
    scheduleInfo = @{ 
        startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ") 
        expiration = @{ 
            type = "AfterDuration" 
            duration = "P180D" 
        }
    }
}

# 3. Payload Injection
try {
    # CRITICAL: Use the IdentityGovernance specific cmdlet.
    $GroupSchedule = New-MgIdentityGovernancePrivilegedAccessGroupEligibilityScheduleRequest -BodyParameter $PimGroupParams -ErrorAction Stop
    Write-Host "SUCCESS: PIM Group Eligibility Established. Schedule ID: $($GroupSchedule.Id)" -ForegroundColor Green
} catch {
    Write-Host "FATAL: Injection failed. $($_.Exception.Message)" -ForegroundColor Red
}

```

---

## Phase 3: Boundary Verification & Expected Behaviors

### 3.1 The 401 Unauthorized Benchmark (Positive Security Indicator)

Attempting to log a standard user (`A.rajavel`) into `portal.azure.com` or `entra.microsoft.com` to check their access **must** result in a `401 Unauthorized` error. Standard users lack the RBAC permissions to view the Azure administration dashboard. **Do not attempt to bypass this.**

### 3.2 End-User Activation Workflow

The user must navigate to the dedicated identity governance portal to request elevation.

1. **Routing:** User navigates to the My Access portal or directly to the PIM activation blade: `https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/aadgroup`
2. **Identification:** User selects the **Groups** tab under "My roles".
3. **Execution:** User locates `SG-Project-Contributors` under the **Eligible assignments** tab and clicks **Activate**.
4. **The Gateway Challenge:** The system successfully intercepts the request, demanding:
* **Justification:** (e.g., "Testing the PIM for Groups").
* **Duration Selection:** Bounded by the 8-hour tenant maximum.
* **MFA Verification:** (If configured in the PIM role settings).


5. **Final State:** The backend provisions the temporary membership and automatically de-provisions it exactly at the end of the requested duration (e.g., `5/25/2026, 4:26:17 AM`).

---

## Post-Execution Assessment

The deployment was mathematically sound. You successfully decoupled standing directory roles from standard resource access. Compromise of the standard user account now yields zero immediate data plane access. The perimeter holds. Move to the next objective.