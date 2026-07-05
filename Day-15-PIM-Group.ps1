# [SANITIZED ON 2026-07-05] SECURITY AUDIT: Hardcoded tenant IDs, credentials, and user emails replaced with generic placeholders for public repo.
<#
    .SYNOPSIS
        Transforms a specified Azure AD Security Group into a PIM-Managed Privileged Access Group
        and provisions Eligible Just-In-Time (JIT) access for a target user.

    .DESCRIPTION
        This script automates the process of converting a standard Azure AD Security Group
        into a Privileged Identity Management (PIM) enabled group. It then assigns
        eligible JIT access to a specified user for a duration of 180 days.
        This is useful for implementing least privilege principles and time-bound access.

#>

# Step-1: Connect to Microsoft Graph API
# Disconnects any existing Graph session to ensure a clean connection.
Disconnect-MgGraph -ErrorAction SilentlyContinue

# Define the required Microsoft Graph API scopes for the connection.
# "User.Read.All": Allows reading all user profiles.
# "Group.Read.All": Allows reading all group properties.
# "PrivilegedAccess.ReadWrite.AzureADGroup": Essential for managing PIM for Groups.
# Connects to the Microsoft Graph API using the specified scopes and Tenant ID.
Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All", "PrivilegedAccess.ReadWrite.AzureADGroup" -TenantID "<YOUR_TENANT_NAME>.onmicrosoft.com"

# Step-2: Initiate PIM for Groups Injection Process
Write-Host "Initiating PIM for Groups Injection..."

# Step-2.1: Define and fetch target group and user details
# Specifies the Display Name of the target Security Group.
$GroupName = "SG-Project-Contributors"
# Specifies the User Principal Name (UPN) of the target user for JIT access.
$TargetUPN = "<TARGET_USER>@<YOUR_TENANT_NAME>.onmicrosoft.com"

# Retrieves the target group object using its Display Name.
$Group = Get-MgGroup -Filter "DisplayName eq '$GroupName'"
# Retrieves the target user object using their User Principal Name.
$User = Get-MgUser -UserId $TargetUPN

# Step-2.2: Validate the existence of the target group and user
if (-not $Group -or -not $User) {
    Write-Host "FATAL: Target Group or User not found." -ForegroundColor Red
    return
}

# Step-3: Construct the payload for the PIM Eligibility Schedule Request
# This hashtable defines the parameters for creating a new PIM eligibility assignment.
$PimGroupParams = @{
    accessId = "member" # Specifies the type of access being assigned (e.g., "member" or "owner").
    principalId = $User.Id # The unique ID of the user (principal) to whom access is being granted.
    groupId = $Group.Id # The unique ID of the group for which access is being granted.
    action = "AdminAssign" # The action being performed (e.g., "AdminAssign" for direct assignment).
    justification = "SC-300: Verified JIT access for single user boundary test." # Justification for the PIM request.
    scheduleInfo = @{ # Defines the schedule for the eligibility.
        startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ") # Start time in UTC.
        expiration = @{ # Defines the expiration settings for the eligibility.
            type = "AfterDuration" # Expiration type: "AfterDuration" for a fixed period.
            duration = "P180D" # Duration of eligibility: "P180D" means 180 days.
        }
    }
}
# Corrected Step-4
try {
    Write-Host "Provisioning JIT Group Eligibility..." -ForegroundColor Cyan

    $GroupSchedule = New-MgIdentityGovernancePrivilegedAccessGroupEligibilityScheduleRequest -BodyParameter $PimGroupParams -ErrorAction Stop

    Write-Host "SUCCESS: PIM Group Eligibility Established -> $($GroupSchedule.Id)" -ForegroundColor Green
} catch {
    Write-Host "FATAL: Failed to provision PIM for Group. $($_.Exception.Message)" -ForegroundColor Red
}
