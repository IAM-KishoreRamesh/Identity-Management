> **[SANITIZED ON 2026-07-05] SECURITY AUDIT:** Hardcoded tenant IDs, credentials, and user emails within this log have been replaced with generic placeholders for public release.

# Phase 1, Week 3: Privileged Access Governance

## Day 14: Privileged Identity Management (PIM) Teardown

**Date of Execution:** May 24, 2026

**Target Identity:** `J.Khiraan@<YOUR_TENANT_NAME>.onmicrosoft.com` (IT Support)

**Target Role:** Helpdesk Administrator (Template ID: `729827e3-9c14-49f7-bb1b-9608f156bbb8`)

### 1. Objective Overview

The fundamental objective of this operation was the eradication of standing administrative privileges to enforce strict Zero Trust access controls.

Prior to this deployment, the IT Support identity held a permanent, Active assignment. A compromised session token would have granted an attacker immediate, unchallenged tenant control. This architecture transitions the identity to **Just-In-Time (JIT) Access**.

**The execution relied on three mandatory pillars:**

1. **The Teardown:** Hunt and programmatically destroy the permanent active assignment.
2. **The Gateway:** Patch the Entra ID PIM policy to mandate an MFA step-up challenge and business justification upon activation.
3. **The Assignment:** Provision an **Eligible** assignment bound by a strict 180-day lifecycle (`P180D`) to force future Access Reviews.

### 2. Infrastructure as Code (IaC) Deployment Script

*Prerequisites: Execution requires a native PowerShell console (to avoid WAM broker suppression) and the `Microsoft.Graph.Identity.SignIns` V2 module.*

```powershell
<#
.SYNOPSIS
    SC-300 Zero Trust Implementation: Privileged Identity Management (PIM) Teardown
.DESCRIPTION
    1) The Teardown: Hunts and eradicates active, standing administrative assignments.
    2) The Gateway: Dynamically locates and patches the Entra ID PIM policy to mandate MFA and Justification.
    3) The Assignment: Injects a Just-In-Time (JIT) eligible assignment bounded by a 180-day hard expiration.
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$TargetUPN = "J.Khiraan@<YOUR_TENANT_NAME>.onmicrosoft.com",
    
    [Parameter(Mandatory=$false)]
    [string]$TenantID = "<YOUR_TENANT_NAME>.onmicrosoft.com"
)

# ==============================================================================
# Step 1: Authentication & Scope Authorization
# ==============================================================================
Disconnect-MgGraph -ErrorAction SilentlyContinue
Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory", "RoleEligibilitySchedule.ReadWrite.Directory", "RoleManagementPolicy.ReadWrite.Directory", "User.Read.All" -TenantId $TenantID

# ==============================================================================
# Step 2: Target Role Acquisition (Immutable IDs)
# ==============================================================================
Write-Host "Acquiring immutable directory targets..." -ForegroundColor Cyan

# Helpdesk Administrator Template ID
$RoleTemplateId = "729827e3-9c14-49f7-bb1b-9608f156bbb8"

# 2.1 Fetch the target Principal ID
$ITUser = Get-MgUser -UserId $TargetUPN
if (-not $ITUser) { throw "FATAL: User $TargetUPN not found in directory." }

# 2.2 Fetch the Role Definition ID
$RoleDef = Get-MgRoleManagementDirectoryRoleDefinition -Filter "TemplateId eq '$RoleTemplateId'"
if (-not $RoleDef) { throw "FATAL: Role definition not found." }

Write-Host "Target User ID: $($ITUser.Id)" 
Write-Host "Role Definition ID: $($RoleDef.Id)" 

# ==============================================================================
# Step 2.3: The Teardown (Eradicate Standing Privileges)
# ==============================================================================
Write-Host "Hunting for active standing assignments for $($ITUser.UserPrincipalName)..." -ForegroundColor Yellow

$ActiveAssignments = Get-MgRoleManagementDirectoryRoleAssignment -Filter "RoleDefinitionId eq '$($RoleDef.Id)' and PrincipalId eq '$($ITUser.Id)'"

if ($ActiveAssignments) {
    foreach ($Assignment in $ActiveAssignments) {
        Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId $Assignment.Id -ErrorAction Stop
        Write-Host "SUCCESS: Destroyed Active Assignment -> $($Assignment.Id)" -ForegroundColor Green
    }
} else {
    Write-Host "No active standing assignments found. Identity is clean." -ForegroundColor Cyan
}

# ==============================================================================
# Step 3: Enforcing the PIM Policy (The Gateway)
# ==============================================================================
Write-Host "Securing PIM Policy gateway for Helpdesk Administrator..." -ForegroundColor Cyan

# 3.1 Fetch the single Policy Assignment for this specific role
$PolicyAssignment = Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$($RoleDef.Id)'"

if (-not $PolicyAssignment) { throw "FATAL: Could not locate PIM Policy Assignment." }

$TargetPolicyId = $PolicyAssignment.PolicyId
$TargetRuleId = "Enablement_Admin_Eligibility" 

Write-Host "Found Target Policy: $TargetPolicyId" -ForegroundColor Yellow
Write-Host "Patching Activation Rule: $TargetRuleId" -ForegroundColor Yellow

# 3.2 Define the strict Zero Trust parameters for the Enablement Rule
$RuleUpdateParams = @{
    "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
    enabledRules = @("Justification", "MultiFactorAuthentication")
}

try {
    # 3.3 Patch the Activation Enablement Rule using the exact IDs
    Update-MgPolicyRoleManagementPolicyRule `
        -UnifiedRoleManagementPolicyId $TargetPolicyId `
        -UnifiedRoleManagementPolicyRuleId $TargetRuleId `
        -BodyParameter $RuleUpdateParams -ErrorAction Stop
        
    Write-Host "SUCCESS: Gateway Secured. MFA and Justification mandated for activation." -ForegroundColor Green
} catch {
    Write-Host "FATAL: Failed to patch PIM Policy. $($_.Exception.Message)" -ForegroundColor Red
    throw
}

# ==============================================================================
# Step 4: Provisioning the PIM Eligibility (The Assignment)
# ==============================================================================
Write-Host "Injecting JIT Eligibility for $($ITUser.UserPrincipalName)..." -ForegroundColor Yellow

$PimParams = @{
    action = "AdminAssign"
    justification = "SC-300 JIT Implementation: Eradicating standing privileges."
    roleDefinitionId = $RoleDef.Id
    directoryScopeId = "/"
    principalId = $ITUser.Id
    scheduleInfo = @{
        startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        expiration = @{
            type = "AfterDuration"
            duration = "P180D" # Corrected ISO 8601 formatting for 180 Days
        }
    }
}

try {
    $PimSchedule = New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $PimParams -ErrorAction Stop
    Write-Host "SUCCESS: PIM Eligibility Established. Request ID: $($PimSchedule.Id)" -ForegroundColor Green
} catch {
    Write-Host "FATAL: Failed to provision PIM assignment. $($_.Exception.Message)" -ForegroundColor Red
    throw
}

```

### 3. Boundary Verification

Code deployment is invalid without physical verification. The following steps confirm the boundary holds:

1. **Active Access Test:** Authenticate as the IT Support user via an Incognito browser. Attempt to execute an administrative action (e.g., reset a standard user password). **Expected Result:** Immediate failure and access denial.
2. **Gateway Challenge Test:** Navigate to **Identity Governance > Privileged Identity Management > My roles**. Locate the *Helpdesk Administrator* role under Eligible assignments and click **Activate**.
3. **MFA Enforcement:** Verify the activation pane explicitly forces a step-up MFA challenge and mandates text justification.
4. **Lifecycle Audit:** Validate in the GUI that the End Time column reflects a 180-day hard limit, explicitly confirming it no longer reads "Permanent."
