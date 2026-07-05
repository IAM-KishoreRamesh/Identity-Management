<#
.SYNOPSIS
    Queries and displays the members of a specific dynamic Microsoft Entra ID group.

.DESCRIPTION
    This script retrieves a specified dynamic security group, then fetches and displays
    the DisplayName and Department of each member within that group. It also provides
    feedback if the group has no members, which can indicate that the dynamic membership
    rule is still processing or is misconfigured.

.NOTES
    Requires: Microsoft.Graph.Groups and Microsoft.Graph.Users modules
    Permissions: Group.Read.All, User.Read.All
#>

# 1. Define the target dynamic group by its DisplayName.
# This assumes the group 'SG-Engineering-Users' has already been created and populated by the dynamic membership engine.
$TargetGroupName = "SG-Engineering-Users"

# Retrieve the group object using its DisplayName.
# -ErrorAction Stop will halt execution if the group is not found or an error occurs.
$EngGroup = Get-MgGroup -Filter "DisplayName eq '$TargetGroupName'" -ErrorAction Stop

# Check if the group was successfully found.
if (-not $EngGroup) {
    Write-Host "ERROR: Group '$TargetGroupName' not found. Please ensure the group exists in Microsoft Entra ID." -ForegroundColor Red
    exit 1 # Exit the script if the target group doesn't exist.
}

Write-Host "Querying membership for $($EngGroup.DisplayName) (ID: $($EngGroup.Id))..." -ForegroundColor Cyan

# 2. Retrieve the members of the dynamic group.
# For dynamic groups, it might take some time for the membership to be fully evaluated by Microsoft Entra ID.
# Get-MgGroupMember returns a collection of directory objects (users, devices, etc.) that are members of the group.
$Members = Get-MgGroupMember -GroupId $EngGroup.Id -ErrorAction Stop

# 3. Process and display the retrieved members.
if ($Members) {
    Write-Host "Found $($Members.Count) members in '$($EngGroup.DisplayName)':" -ForegroundColor Green
    foreach ($member in $Members) {
        # Retrieve additional user details (DisplayName, Department) for each member.
        # This is necessary because Get-MgGroupMember only returns basic object information (like ID).
        $User = Get-MgUser -UserId $member.Id -Select DisplayName, Department -ErrorAction Stop
        Write-Host "  - $($User.DisplayName) (ID: $($member.Id)) - Dept: $($User.Department)" -ForegroundColor Green
    }
} else {
    # This message indicates that either the dynamic rule is still processing,
    # or the rule itself did not match any users, or there was an issue retrieving members.
    Write-Host "EMPTY: The dynamic group '$($EngGroup.DisplayName)' currently has no members." -ForegroundColor Red
    Write-Host "       This could mean the dynamic group engine is still evaluating, or the membership rule failed to match any users." -ForegroundColor Yellow
}