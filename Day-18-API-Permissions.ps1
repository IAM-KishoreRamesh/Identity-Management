# [SANITIZED ON 2026-07-05] SECURITY AUDIT: Hardcoded tenant IDs, credentials, and user emails replaced with generic placeholders for public repo.
Disconnect-MgGraph -ErrorAction SilentlyContinue
Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All" -TenantId "<YOUR_TENANT_NAME>.onmicrosoft.com"

Write-Host "Initiating Graph API Permission Injection for OIM Sync Engine..." -ForegroundColor Cyan

# 1. Target the Workload Identity using the Client ID generated on Day 17
$ClientAppId = "<YOUR_CLIENT_ID>"
$TargetSP = Get-MgServicePrincipal -Filter "AppId eq '$ClientAppId'"

if (-not $TargetSP) {
    Write-Host "FATAL ERROR: Target Service Principal not found. Double-check Day 17 execution." -ForegroundColor Red
    return
}

# 2. Locate the First-Party Microsoft Graph Service Principal in the tenant
# The AppID '00000003-0000-0000-c000-000000000000' is the universal immutable identifier for Microsoft Graph
$GraphSP = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

if (-not $GraphSP) {
    Write-Host "FATAL ERROR: Failed to resolve the Microsoft Graph Service Principal engine." -ForegroundColor Red
    return
}

# 3. Filter and isolate the specific App Role ID for User.ReadWrite.All (Application type)
$AppRole = $GraphSP.AppRoles | Where-Object { $_.Value -eq "User.ReadWrite.All" -and $_.AllowedMemberTypes -contains "Application" }

if (-not $AppRole) {
    Write-Host "FATAL ERROR: Could not locate the 'User.ReadWrite.All' application role definition." -ForegroundColor Red
    return
}

# 4. Construct the structural AppRole Assignment payload
$AssignmentParams = @{
    principalId = $TargetSP.Id          # The identity receiving the power
    resourceId  = $GraphSP.Id           # The resource engine granting the power (Graph API)
    appRoleId   = $AppRole.Id           # The specific permission ID being bound
}

# 5. Inject the permission block onto the tenant backend
try {
    Write-Host "Injecting role assignment onto Service Principal ID: $($TargetSP.Id)..." -ForegroundColor Yellow
    $Assignment = New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $TargetSP.Id -BodyParameter $AssignmentParams -ErrorAction Stop
    Write-Host "SUCCESS: 'User.ReadWrite.All' application permission successfully assigned." -ForegroundColor Green
} catch {
    Write-Host "CRITICAL FAILURE: Permission assignment failed -> $($_.Exception.Message)" -ForegroundColor Red
}
