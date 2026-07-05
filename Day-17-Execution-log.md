> **[SANITIZED ON 2026-07-05] SECURITY AUDIT:** Hardcoded tenant IDs, credentials, and user emails within this log have been replaced with generic placeholders for public release.

# Day 17 Execution Log: Workload Identity & API Bridge Provisioning

## 1. Architectural Objective

The fundamental objective of this operation is the transition from human-centric identity models to a programmatic, non-human **Workload Identity**.

Prior to this deployment, all operations within the control plane required interactive user authentication, which mandates multi-factor authentication (MFA) prompts, session cookies, and manual human intervention. For the Phase 2 automation pipeline (OIM-to-Entra ID identity synchronization), a background synchronization script must execute headlessly on a server. Because a script cannot solve interactive MFA challenges, this deployment establishes an **App Registration** and an associated **Service Principal** acting as a secure, machine-level account leveraging the **OAuth 2.0 Client Credentials Grant Type**.

---

## 2. Target Environment State

The following immutable infrastructure parameters were established during the execution window:

| Parameter | Value / Object Identifier |
| --- | --- |
| **Target Tenant** | `<YOUR_TENANT_NAME>.onmicrosoft.com` |
| **Workload Identity Name** | `OIM-12c-Sync-Engine` |
| **Sign-In Audience** | `AzureADMyOrg` (Single-Tenant Enforced) |
| **Application (Client) ID** | `<YOUR_CLIENT_ID>` |
| **Credential Type** | Cryptographic Client Secret |
| **Secret Expiration Policy** | 6-Month Hard Bound (`CurrentTime + 180 Days`) |

> [!WARNING]
> **Cryptographic Secret Exposure Warning**
> The generated Client Secret value was printed to the secure terminal session exactly once. On-backend hashing algorithms mask this value immediately upon creation. It has been extracted and committed to the local secure vault. If lost, the credential plane must be revoked and rotated immediately; retrieval is structurally impossible.

---

## 3. Infrastructure as Code (IaC) Deployment Script

The deployment was executed natively via the Microsoft Graph PowerShell SDK using the `Application.ReadWrite.All` control plane scope.

```powershell
Write-Host "Initiating OIM 12c API Bridge Provisioning..." -ForegroundColor Cyan

# ==============================================================================
# 1. AUTHENTICATION & SESSION MANAGEMENT
# ==============================================================================
Disconnect-MgGraph -ErrorAction SilentlyContinue

# Authenticate the administrator to the target Entra ID directory.
Connect-MgGraph -Scopes "Application.ReadWrite.All" -TenantId "<YOUR_TENANT_NAME>.onmicrosoft.com" -UseDeviceAuthentication

# ==============================================================================
# 2. CREATE THE APP REGISTRATION (THE GLOBAL BLUEPRINT)
# ==============================================================================
$AppParams = @{
    displayName = "OIM-12c-Sync-Engine" 
    signInAudience = "AzureADMyOrg"     
}

$App = New-MgApplication -BodyParameter $AppParams
Write-Host "App Registration Created successfully." -ForegroundColor Green

# ==============================================================================
# 3. INSTANTIATE THE SERVICE PRINCIPAL (THE LOCAL INSTANCE)
# ==============================================================================
# Instantiates the local operating entity (Enterprise Application) mapping to the App ID
$SP = New-MgServicePrincipal -AppId $App.AppId

# ==============================================================================
# 4. GENERATE THE CLIENT SECRET (THE PASSWORD)
# ==============================================================================
Write-Host "Generating secure Client Secret..." -ForegroundColor Cyan

$SecretParams = @{
    passwordCredential = @{
        displayName = "OIM-Sync-Secret-01"
        endDateTime = (Get-Date).AddMonths(6).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
}

$Secret = Add-MgApplicationPassword -ApplicationId $App.Id -BodyParameter $SecretParams

# ==============================================================================
# 5. OUTPUT THE CREDENTIALS FOR THE PYTHON SCRIPT
# ==============================================================================
Write-Host ""
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host "        VAULT THESE CREDENTIALS NOW    " -ForegroundColor Red
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host "Tenant ID:     <YOUR_TENANT_NAME>.onmicrosoft.com"
Write-Host "Client ID:     $($App.AppId)"               
Write-Host "Client Secret: $($Secret.SecretText)"       
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host "WARNING: The Client Secret will NEVER be visible again after this session." -ForegroundColor Red

```

---

## 4. Operational Boundary Verification

To validate that the execution completed cleanly on the cloud tenant provider side, the following verification points must be physically inspected:

1. **Identity Object Materialization:** Navigate to `entra.microsoft.com` > **Identity** > **Applications** > **App registrations** > **All applications**. Search for `OIM-12c-Sync-Engine`. Verify structural convergence.
2. **Audience Constraint Validation:** Under the application overview blade, confirm that the Supported Account Types property explicitly shows **My organization only (Single tenant)**.
3. **Credential Lifecycle Audit:** Navigate to the **Certificates & secrets** panel of the application. Validate that one secret entry exists under the name `OIM-Sync-Secret-01` and that its expiration date is explicitly bound to exactly 6 months from today's deployment date.

---
