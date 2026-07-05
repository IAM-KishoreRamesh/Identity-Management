# [SANITIZED ON 2026-07-05] SECURITY AUDIT: Hardcoded tenant IDs, credentials, and user emails replaced with generic placeholders for public repo.
Write-Host "Initiating OIM 12c API Bridge Provisioning..." -ForegroundColor Cyan

# ==============================================================================
# 1. AUTHENTICATION & SESSION MANAGEMENT
# ==============================================================================

# Forcefully disconnect any stale Graph sessions to ensure we are starting fresh
Disconnect-MgGraph -ErrorAction SilentlyContinue

# Authenticate the administrator to the target Entra ID directory.
# -Scopes: Requests the exact permission needed to create an identity object.
# -TenantId: Directs the login to your specific organization.
# -UseDeviceAuthentication: Prevents headless/background errors by using a 
#                           device code instead of trying to pop open a browser.
Connect-MgGraph -Scopes "Application.ReadWrite.All" -TenantId "<YOUR_TENANT_NAME>.onmicrosoft.com" -UseDeviceAuthentication


# ==============================================================================
# 2. CREATE THE APP REGISTRATION (THE GLOBAL BLUEPRINT)
# ==============================================================================

# Define the properties for the new Workload Identity
$AppParams = @{
    displayName = "OIM-12c-Sync-Engine" # The "Username" we will see in the Azure Portal
    signInAudience = "AzureADMyOrg"     # Restricts this identity to your tenant only (No external access)
}

# Execute the creation of the App Registration object in Entra ID
$App = New-MgApplication -BodyParameter $AppParams
Write-Host "App Registration Created successfully." -ForegroundColor Green


# ==============================================================================
# 3. INSTANTIATE THE SERVICE PRINCIPAL (THE LOCAL INSTANCE)
# ==============================================================================

# While the App Registration above defines the app, the Service Principal is the 
# actual local entity that operates in your directory and holds API permissions.
# We map it directly to the App Registration's ID.
$SP = New-MgServicePrincipal -AppId $App.AppId


# ==============================================================================
# 4. GENERATE THE CLIENT SECRET (THE PASSWORD)
# ==============================================================================
Write-Host "Generating secure Client Secret..." -ForegroundColor Cyan

# Define the properties for the cryptographic password
$SecretParams = @{
    passwordCredential = @{
        displayName = "OIM-Sync-Secret-01"
        # Enforce strict credential rotation by hardcoding an expiration exactly 
        # 6 months from the current time. This limits exposure if leaked.
        endDateTime = (Get-Date).AddMonths(6).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
}

# Attach the new password to the App Registration
$Secret = Add-MgApplicationPassword -ApplicationId $App.Id -BodyParameter $SecretParams


# ==============================================================================
# 5. OUTPUT THE CREDENTIALS FOR THE PYTHON SCRIPT
# ==============================================================================
# Print the connection strings needed for the OAuth 2.0 Client Credentials flow.
# These will be loaded via environment variables in your Python script.

Write-Host ""
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host "        VAULT THESE CREDENTIALS NOW    " -ForegroundColor Red
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host "Tenant ID:     <YOUR_TENANT_NAME>.onmicrosoft.com"
Write-Host "Client ID:     $($App.AppId)"               # The background script's Username
Write-Host "Client Secret: $($Secret.SecretText)"       # The background script's Password
Write-Host "=======================================" -ForegroundColor Yellow

# Critical Security Reminder: Graph API obscures the secret text immediately 
# after generation. If it is lost, it must be destroyed and recreated.
Write-Host "WARNING: The Client Secret will NEVER be visible again after this session." -ForegroundColor Red
