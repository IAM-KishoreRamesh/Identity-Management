<#
.SYNOPSIS
    Automates the creation of Microsoft Entra ID (Azure AD) Dynamic Security Groups.

.DESCRIPTION
    This script iterates through a predefined list of departments and creates dynamic security groups 
    using the Microsoft Graph PowerShell SDK. It configures membership rules based on the user's 
    department attribute and enables automatic rule processing.

.NOTES
    Requires: Microsoft.Graph.Groups module
    Permissions: Group.ReadWrite.All
#>

# 1. Define Group Configuration
# Each entry defines the display name, mail alias, and the OData filter rule for membership.
$Groups = @(
        @{
            DisplayName = "SG-Engineering-Users"
            MailNickname = "SG_Engineering"
            MembershipRule = '(user.department -eq "Engineering")'
        }
        @{
            DisplayName = "SG-HR-Users"
            MailNickname = "SG_HR"
            MembershipRule = '(user.department -eq "HR")'
        }
        @{
            DisplayName = "SG-ITSupport-Users"
            MailNickname = "SG_ITSupport"
            MembershipRule = '(user.department -eq "IT Support")'
        }
)

# 2. Iterate and Create Dynamic Groups
foreach ($GroupConfig in $Groups) {
    try {
        # Splatting parameters for New-MgGroup to improve readability
        $GroupParams = @{
            DisplayName                    = $GroupConfig.DisplayName
            MailEnabled                    = $false
            MailNickname                   = $GroupConfig.MailNickname
            SecurityEnabled                = $true
            # 'DynamicMembership' identifies this as a dynamic group rather than a static one
            GroupTypes                     = @("DynamicMembership")
            # The OData query that defines who belongs in the group
            MembershipRule                 = $GroupConfig.MembershipRule
            # 'On' ensures the dynamic engine starts evaluating members immediately
            MembershipRuleProcessingState  = "On"
        }

        Write-Host "Creating group: $($GroupConfig.DisplayName)..." -ForegroundColor Cyan
        
        # Execute group creation
        New-MgGroup @GroupParams -ErrorAction Stop
        
        Write-Host "SUCCESS: Dynamic group '$($GroupConfig.DisplayName)' created successfully." -ForegroundColor Green
    }
    catch {
        # Catch errors such as 'Group already exists' or 'Insufficient privileges'
        Write-Host "FAILED: $($GroupConfig.DisplayName) -> $($_.Exception.Message)" -ForegroundColor Red
    }
}