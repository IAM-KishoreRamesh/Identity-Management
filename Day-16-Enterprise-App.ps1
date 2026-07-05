# [SANITIZED ON 2026-07-05] SECURITY AUDIT: Hardcoded tenant IDs, credentials, and user emails replaced with generic placeholders for public repo.
# Script Name: Day-16-Enterprise-App.ps1
# Description: Automates the creation of an Azure AD Application Registration and Service Principal, 
#              enforcing strict user assignment (Zero Trust).
# Requirements: Microsoft.Graph.Applications module

# 0. Authentication and Environment Setup
# Ensure any existing Graph sessions are closed to prevent permission bleeding
Disconnect-MgGraph -ErrorAction SilentlyContinue

# Connect to Microsoft Graph with specific permissions:
# - Application.ReadWrite.All: Required to create the App Registration
# - AppRoleAssignment.ReadWrite.All: Required to manage service principal properties
Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All" -TenantId "<YOUR_TENANT_NAME>.onmicrosoft.com"

Write-Host "Initiating Enterprise Application Provisioning..." -ForegroundColor Cyan

# 1. Create the Application Registration
# The Application object acts as the global definition/template for the identity.
$AppParams = @{
    displayName = "Project Alpha SaaS Dashboard"
    signInAudience = "AzureADMyOrg" # Restricts sign-in to the local tenant only (Single-tenant)
}
$App = New-MgApplication -BodyParameter $AppParams
Write-Host "Application Registration Created: $($App.AppId)" -ForegroundColor Yellow

# 2. Create the Service Principal
# The Service Principal is the local instance (Enterprise App) of the global application.
# This object is what permissions are actually granted to within this specific tenant.
$SPParams = @{
    appId = $App.AppId
}
$SP = New-MgServicePrincipal -BodyParameter $SPParams
Write-Host "Service Principal Created: $($SP.Id)" -ForegroundColor Yellow

# 3. Security Hardening: Enforce Zero-Trust Assignment
Write-Host "Enforcing strict assignment requirement..." -ForegroundColor Cyan

try {
    # Notice the colon syntax to strictly bind the boolean, and the ErrorAction directive.
    Update-MgServicePrincipal -ServicePrincipalId $SP.Id -AppRoleAssignmentRequired:$true -ErrorAction Stop
    Write-Host "SUCCESS: Application locked and ready for governance binding." -ForegroundColor Green
} catch {
    Write-Host "FATAL: Failed to enforce strict assignment. Application is unsecured." -ForegroundColor Red
    Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Red
    # Halt execution so subsequent scripts don't assume the app is secured
    return 
}
