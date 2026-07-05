# [SANITIZED ON 2026-07-05] SECURITY AUDIT: Hardcoded tenant IDs, credentials, and user emails replaced with generic placeholders for public repo.
<#
    Goal: To automatically remove an disabled account

    Phase-1: Strip the user from the dynamic group
    Phase-2: Removed the user from all the inherited licenses
    Phase-3: Block subsequent login attempts
#>

# Step-1: Authentication to login into Azure using Graph API
Disconnect-MgGraph -ErrorAction SilentlyContinue
Connect-MgGraph -Scopes "User.ReadWrite.All", "User.RevokeSessions.All", "Group.Read.All" -TenantID "<YOUR_TENANT_NAME>.onmicrosoft.com"

# Step-2: Remove one random user from SG-Engineering-Users groups (exceptions added)
Write-Host "Initiating Automated Offboarding Sequence..." -ForegroundColor Cyan

$ExcludedUPN = "<TARGET_USER>@<YOUR_TENANT_NAME>.onmicrosoft.com"
$TargetGroup = Get-MgGroup -Filter "DisplayName eq 'SG-Engineering-Users'"

# Hydrate the full user objects before filtering
$TargetUser = Get-MgGroupMember -GroupId $TargetGroup.Id -All | 
    ForEach-Object { Get-MgUser -UserId $_.Id -Property "id,displayName,userPrincipalName" } |
    Where-Object { $_.UserPrincipalName -ne $ExcludedUPN } | 
    Get-Random -Count 1

if (-not $TargetUser){
    Write-Host "No Engineering User found for termination." -ForegroundColor Red
    return
}

Write-Host "Target Acquired: $($TargetUser.DisplayName) ($($TargetUser.userPrincipalName))" -ForegroundColor Yellow

try {
    # 2. Disable Account and Modify Attribute (Triggers Dynamic Group Eviction)
    Write-Host "Disabling account and updating department to 'Terminated'..."
    Update-MgUser -UserId $TargetUser.Id -AccountEnabled:$false -Department "Terminated" -ErrorAction Stop

    # 3. Force Token Revocation (Suppress boolean output)
    Write-Host "Revoking all active refresh and session tokens..." 
    Revoke-MgUserSignInSession -UserId $TargetUser.Id -ErrorAction Stop | Out-Null

    Write-Host "SUCCESS: Identity state modified and sessions killed." -ForegroundColor Green
}
catch {
    Write-Host "FAILED TO EXECUTE OFFBOARDING: $($_.Exception.Message)" -ForegroundColor Red
}
