Write-Host "Hunting for Terminated User..." -ForegroundColor Cyan

# 1. Dynamically locate the user we just terminated
$TerminatedUser = Get-MgUser -Filter "Department eq 'Terminated'" -Top 1

if (-not $TerminatedUser) {
    Write-Host "FAILED: Could not locate a user with the 'Terminated' department." -ForegroundColor Red
    return
}

Write-Host "Target Acquired: $($TerminatedUser.DisplayName)" -ForegroundColor Yellow

# 2. Verify Group Removal
$EngGroup = Get-MgGroup -Filter "DisplayName eq 'SG-Engineering-Users'"
$StillInGroup = Get-MgGroupMember -GroupId $EngGroup.Id | Where-Object { $_.Id -eq $TerminatedUser.Id }

if ($StillInGroup) {
    Write-Host "FAIL: User is still in the Engineering Group." -ForegroundColor Red
} else {
    Write-Host "PASS: User successfully stripped from dynamic group." -ForegroundColor Green
}

# 3. Verify License Revocation
$Licenses = Get-MgUserLicenseDetail -UserId $TerminatedUser.Id
if ($Licenses.Count -eq 0) {
    Write-Host "PASS: P2 License successfully revoked." -ForegroundColor Green
} else {
    Write-Host "FAIL: User still holds active licenses." -ForegroundColor Red
}