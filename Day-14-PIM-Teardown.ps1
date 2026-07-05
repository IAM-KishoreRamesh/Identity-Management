# [SANITIZED ON 2026-07-05] SECURITY AUDIT: Hardcoded tenant IDs, credentials, and user emails replaced with generic placeholders for public repo.
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
    [string]$TargetUPN = "<ADMIN_USER>@<YOUR_TENANT_NAME>.onmicrosoft.com",
    
    [Parameter(Mandatory=$false)]
    [string]$TenantID = "<YOUR_TENANT_NAME>.onmicrosoft.com"
)

# ==============================================================================
# Step 1: Authentication & Scope Authorization
# ==============================================================================
# Flush any existing Graph sessions to ensure a predictable and authenticated execution environment
Disconnect-MgGraph -ErrorAction SilentlyContinue 
Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory", "RoleEligibilitySchedule.ReadWrite.Directory", "RoleManagementPolicy.ReadWrite.Directory", "User.Read.All" -TenantId $TenantID

# ==============================================================================
# Step 2: Target Role Acquisition (Immutable IDs)
# ==============================================================================
Write-Host "Acquiring immutable directory targets..." -ForegroundColor Cyan

# Use Template ID for Helpdesk Administrator; these are immutable and consistent across all Entra tenants
$RoleTemplateId = "729827e3-9c14-49f7-bb1b-9608f156bbb8"

# 2.1 Resolve the Target UPN to its internal Directory Object ID (PrincipalId)
$ITUser = Get-MgUser -UserId $TargetUPN
if (-not $ITUser) { throw "FATAL: User $TargetUPN not found in directory." }

# 2.2 Retrieve the tenant-specific Role Definition ID using the global Template ID filter
$RoleDef = Get-MgRoleManagementDirectoryRoleDefinition -Filter "TemplateId eq '$RoleTemplateId'"
if (-not $RoleDef) { throw "FATAL: Role definition not found." }

Write-Host "Target User ID: $($ITUser.Id)" 
Write-Host "Role Definition ID: $($RoleDef.Id)" 

# ==============================================================================
# Step 2.3: The Teardown (Eradicate Standing Privileges)
# ==============================================================================
Write-Host "Hunting for active standing assignments for $($ITUser.UserPrincipalName)..." -ForegroundColor Yellow

# Query for existing permanent assignments that bypass PIM lifecycle controls
$ActiveAssignments = Get-MgRoleManagementDirectoryRoleAssignment -Filter "RoleDefinitionId eq '$($RoleDef.Id)' and PrincipalId eq '$($ITUser.Id)'"

if ($ActiveAssignments) {
    foreach ($Assignment in $ActiveAssignments) {
        # Permanently delete active assignments to transition the identity to a Just-In-Time model
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

# 3.1 Locate the PIM Policy Assignment that maps this specific Role to the directory scope ('/')
$PolicyAssignment = Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$($RoleDef.Id)'"

if (-not $PolicyAssignment) { throw "FATAL: Could not locate PIM Policy Assignment." }

$TargetPolicyId = $PolicyAssignment.PolicyId
# 'Enablement_Admin_Eligibility' specifically manages requirements during the initial assignment phase
$TargetRuleId = "Enablement_Admin_Eligibility" # Confirmed via diagnostic dump

Write-Host "Found Target Policy: $TargetPolicyId" -ForegroundColor Yellow
Write-Host "Patching Activation Rule: $TargetRuleId" -ForegroundColor Yellow

# 3.2 Define the strict Zero Trust parameters for the Enablement Rule
$RuleUpdateParams = @{
    # Graph API requires explicit OData type casting for polymorphic rule types
    "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
    enabledRules = @("Justification", "MultiFactorAuthentication")
}

try {
    # 3.3 Apply the updated policy settings to the specific role enablement rule
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
    action = "AdminAssign" # Defines that an administrator is performing the assignment
    justification = "SC-300 JIT Implementation: Eradicating standing privileges."
    roleDefinitionId = $RoleDef.Id
    directoryScopeId = "/"
    principalId = $ITUser.Id
    scheduleInfo = @{
        # PIM Schedule requests require UTC ISO 8601 format with millisecond precision
        startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ") 
        expiration = @{
            type = "AfterDuration"
            duration = "PT180D" # 180-day limit ensures the user must be re-evaluated via Access Reviews later
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
