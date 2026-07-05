<#
.SYNOPSIS
    Simulates a "Mover" scenario by changing a user's department.

.DESCRIPTION
    This script finds a user currently in the Engineering department and updates their 
    department to HR. This is used to test the responsiveness of Dynamic Groups 
    and License assignments based on attribute changes.

.NOTES
    Requires: Microsoft.Graph.Users module
    Permissions: User.ReadWrite.All
#>

# 1. Target one specific Engineering user
# Selecting the first user found to minimize impact during testing.
$TargetUser = Get-MgUser -Filter "Department eq 'Engineering'" -Top 1
Write-Host "Selected User: $($TargetUser.DisplayName)" -ForegroundColor Cyan

# 2. Execute the attribute change
Write-Host "Executing 'Mover' Scenario: Changing department to HR..." -ForegroundColor Cyan
Update-MgUser -UserId $TargetUser.Id -Department "HR"

# 3. Verify the attribute updated successfully
$VerifyUser = Get-MgUser -UserId $TargetUser.Id -Select Department
Write-Host "New Department State: $($VerifyUser.Department)" -ForegroundColor Yellow