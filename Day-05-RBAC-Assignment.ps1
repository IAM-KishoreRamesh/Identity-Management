<#
.SYNOPSIS
    Assigns specific Azure AD (Entra ID) directory roles to randomly selected users from predefined groups.

.DESCRIPTION
    This script demonstrates how to fetch dynamic groups, retrieve their members,
    select a random user from each group, and then assign specific directory roles
    (Helpdesk Administrator and Security Reader) to these users using Microsoft Graph PowerShell.
    It includes steps for fetching role definitions and creating role assignments.

.NOTES
    File Name: Day-05-RBAC-Assignment.ps1
    Requires: Microsoft.Graph.Groups, Microsoft.Graph.Users, and Microsoft.Graph.Identity.DirectoryManagement modules.
    Ensure you have authenticated with sufficient permissions (e.g., RoleManagement.ReadWrite.Directory, Group.Read.All, User.Read.All).
#>

# 0. AUTHENTICATION AND MODULE LOADING (Implicitly assumed from previous steps or environment) ###
# Ensure you are connected to Microsoft Graph with appropriate scopes, e.g.:
# Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All", "RoleManagement.ReadWrite.Directory"

# 1. Fetch the targeted Dynamic Groups ############################################################
# Retrieve the Azure AD groups by their DisplayName.
# These groups are assumed to be dynamic groups, but the fetching mechanism works for any group type.
$EngGroup = Get-MgGroup -Filter "DisplayName eq 'SG-Engineering-Users'"
$ITGroup = Get-MgGroup -Filter "DisplayName eq 'SG-ITSupport-Users'"

# 2. Fetch all the users present in these groups ##################################################
# Get all members (users) of the Engineering and IT Support groups using their respective IDs.
$AllEngUsers = Get-MgGroupMember -GroupId $EngGroup.Id 
$AllITUsers = Get-MgGroupMember -GroupId $ITGroup.ID

# 3. Get a random user from the Engineering and ITSupport groups ##################################
# Select one random user object from the list of all members for each group.
$RandomEngUser = $AllEngUsers | Get-Random 
$RandomITUser = $AllITUsers | Get-Random

# 4. Fetch the Random users' details ##############################################################
# Retrieve the full user details for the randomly selected users using their IDs.
$EngUserDetails = Get-MgUser -UserId $RandomEngUser.Id
$ITUserDetails = Get-MgUser -UserId $RandomITUser.Id

# Display the details of the randomly selected users for verification.
Write-Host "Randomly Selected Engineer: $($EngUserDetails.DisplayName) ($($EngUserDetails.UserPrincipalName))"
Write-Host "Randomly Selected IT User: $($ITUserDetails.DisplayName) ($($ITUserDetails.UserPrincipalName))"

# 5. Fetch role definitions from Entra ID #########################################################
Write-Host "Retrieving the role definitions from Entra ID ..." -foregroundColor Cyan
# Get the specific directory role definitions by their DisplayName.
# These are built-in Azure AD roles.
$HelpdeskRole = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Helpdesk Administrator'"
$SecurityReaderRole = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Security Reader'"

# 6. Assign the Helpdesk Administrator role to the IT Support User ################################
# Define the parameters for the role assignment using a hashtable for splatting.
$HelpdeskAssignment = @{
    PrincipalId      = $ITUserDetails.Id        # The ID of the user to whom the role will be assigned.
    RoleDefinitionId = $HelpdeskRole.Id         # The ID of the role definition to assign.
    DirectoryScopeId = "/"                      # The scope of the assignment. "/" indicates tenant-wide.
}
Write-Host "Assigning 'Helpdesk Administrator' to $($ITUserDetails.DisplayName)..." -ForegroundColor Yellow
# Create the new role assignment. -ErrorAction Stop will halt the script if the assignment fails.
New-MgRoleManagementDirectoryRoleAssignment @HelpdeskAssignment -ErrorAction Stop

# 7. Assign Security Reader to the Engineering User ###############################################
# Define the parameters for the role assignment using a hashtable for splatting.
$SecurityAssignment = @{
    PrincipalId      = $EngUserDetails.Id       # The ID of the user to whom the role will be assigned.
    RoleDefinitionId = $SecurityReaderRole.Id   # The ID of the role definition to assign.
    DirectoryScopeId = "/"                      # The scope of the assignment. "/" indicates tenant-wide.
}
Write-Host "Assigning 'Security Reader' to $($EngUserDetails.DisplayName)..." -ForegroundColor Yellow
# Create the new role assignment. -ErrorAction Stop will halt the script if the assignment fails.
New-MgRoleManagementDirectoryRoleAssignment @SecurityAssignment -ErrorAction Stop

# 8. Completion Message ###########################################################################
Write-Host "SUCCESS: Directory Roles Provisioned." -ForegroundColor Green