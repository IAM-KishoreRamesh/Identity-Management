# Architecture Document: Day 10 – Conditional Access Baseline

## 1. Objective: Shifting the Security Perimeter

The goal is to establish a foundational Zero-Trust identity perimeter at the directory edge using Microsoft Entra ID Conditional Access. This phase eliminates reliance on primary authentication (passwords) for high-privilege roles and permanently seals the tenant against legacy protocol bypass attacks.

**Core Policies Deployed:**

* **CA01:** Block Legacy Authentication (Tenant-Wide).
* **CA02:** Require MFA for Administrators (Global & Helpdesk Admins).

## 2. Environmental Prerequisites & Constraints

You cannot deploy custom Conditional Access policies via the Microsoft Graph API if Microsoft's baseline protections are active. They are mutually exclusive.

* **Security Defaults:** Must be set to **Disabled** in `Entra ID > Properties`. Attempting deployment with this enabled results in an immediate API payload rejection.
* **Authentication Scopes:** The deployment requires a high-privilege OAuth token. The executing session must hold: `Policy.ReadWrite.ConditionalAccess`, `Policy.Read.All`, `Application.Read.All`, and `Directory.Read.All`.
* **Lockout Failsafe:** A dedicated "Break-Glass" emergency access account (`emergency.admin@...`) must exist. **Critical:** You must use the user's **User Object ID**, not the Device Object ID. Injecting a Device ID into a User exclusion array will result in permanent tenant lockout.

## 3. Infrastructure as Code (Deployment Script)

The following PowerShell payload constructs and pushes the JSON definitions directly to the Entra ID control plane using the Graph API.

```powershell
<#
    Goal: Deploy Zero-Trust Conditional Access Baseline
    Execution: Connect-MgGraph required with Policy, Application, and Directory scopes.
#>

Write-Host "Deploying Zero-Trust Conditional Access Baseline..." -ForegroundColor Cyan

# ID for the 'Break-Glass' User Object to prevent accidental lockout
$EmergencyAccessObjectId = "xxxxx-xxxxxx-xxxxxxxxxx-xxxxxxxx-xxxxxx"

# ==========================================
# POLICY 1: Block Legacy Authentication
# ==========================================
$LegacyAuthParams = @{
    displayName = "CA01: Block Legacy Authentication" # UI: Policy Name
    state       = "enabled"                         # UI: Enable Policy -> On
    conditions = @{
        users = @{                                  # UI: Assignments > Users
            includeUsers = @("All")                 # UI: Include > All users
            excludeUsers = @($EmergencyAccessObjectId) # UI: Exclude > Break-Glass
        }
        applications = @{
            includeApplications = @("All")          # UI: Target Resources > All Cloud Apps
        }
        clientAppTypes = @("exchangeActiveSync", "other") # UI: Conditions > Client Apps (Legacy)
    }
    grantControls = @{ 
        operator = "OR" 
        builtInControls = @("block")
    }
}

# ==========================================
# POLICY 2: Require MFA for Admins
# ==========================================
$DirectoryRoleIds = @( 
    "62e90394-69f5-4237-9190-012177145e10", # Global Administrator
    "729827e3-9c14-49f7-bb1b-9608f156bbb8"  # Helpdesk Administrator
)

$MfaAdminParams = @{
    displayName = "CA02: Require MFA for Administrators" # UI: Policy Name
    state       = "enabled" 
    conditions = @{
        users = @{ 
            includeRoles = $DirectoryRoleIds        # UI: Assignments > Directory Roles
            excludeUsers = @($EmergencyAccessObjectId)
        }
        applications = @{ 
            includeApplications = @("All") 
        }
    }
    grantControls = @{                              # UI: Access Controls > Grant
        operator = "OR" 
        builtInControls = @("mfa") 
    }
}

# ==========================================
# EXECUTION
# ==========================================
Write-Host "Deploying Policies to Directory Edge..." -ForegroundColor Yellow

try {
    $LegacyPolicy = New-MgIdentityConditionalAccessPolicy -BodyParameter $LegacyAuthParams -ErrorAction Stop
    Write-Host "[SUCCESS] CA01 Deployed -> $($LegacyPolicy.Id)" -ForegroundColor Green
} catch {
    Write-Host "[FAILED] CA01: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    $MfaPolicy = New-MgIdentityConditionalAccessPolicy -BodyParameter $MfaAdminParams -ErrorAction Stop
    Write-Host "[SUCCESS] CA02 Deployed -> $($MfaPolicy.Id)" -ForegroundColor Green
} catch {
    Write-Host "[FAILED] CA02: $($_.Exception.Message)" -ForegroundColor Red
}

```

## 4. Boundary Verification Methodology

Terminal output is insufficient for IAM verification. The perimeter must be actively tested.

### Phase 1: Simulated Evaluation ("What If" Engine)

Utilize the Entra ID *What If* tool to validate the routing logic without causing business disruption.

* **Target: Standard User / Legacy Protocol:** Verify *CA01* triggers with a **Block** grant control.
* **Target: Admin User / Modern Browser:** Verify *CA02* triggers with an **Require MFA** grant control.
* **Target: Break-Glass Admin:** Verify both policies appear under the **Policies that will not apply** tab due to explicit user exclusion.

### Phase 2: Active Penetration Test

Execute a physical login attempt using an Incognito/InPrivate session.

* **Helpdesk Administrator:** The system successfully interrupts the flow and forces the user into the MFA registration wizard.
* **Global Administrator (AADSTS50076 Edge Case):** If the Global Admin lacks a registered authentication method, the portal login may crash with error `AADSTS50076`. This indicates the policy correctly blocked access, but the specific application URL failed to redirect to the registration campaign.
* *Resolution:* Bootstrap the account by navigating directly to `https://mysignins.microsoft.com/security-info` to force the method registration.



## 5. Architectural Flaw & Next Steps

This baseline secures authentication, but the architecture retains a severe flaw: **Standing Privileges**.
The Global Administrator and Helpdesk Administrator directory roles are permanently assigned. If a session cookie is stolen via an Adversary-in-the-Middle (AiTM) attack, the MFA prompt is bypassed, and the attacker gains permanent access.