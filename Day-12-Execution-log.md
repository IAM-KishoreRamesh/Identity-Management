> **[SANITIZED ON 2026-07-05] SECURITY AUDIT:** Hardcoded tenant IDs, credentials, and user emails within this log have been replaced with generic placeholders for public release.

# Technical Runbook: Day 12 - Risk-Based Governance (Entra ID Protection)

## 1. Architectural Objective

Transition the tenant from a static security perimeter to a dynamic, machine-learning-driven Zero Trust architecture. Static Conditional Access policies evaluate facts (user, group, application) but are blind to context. Identity Protection ingests telemetry (e.g., anonymous routing, leaked credentials) to evaluate the probability of compromise and automate remediation.

## 2. Policy Definitions & Scope

This deployment establishes two distinct risk boundaries. You must understand the technical difference between a compromised action and a compromised asset.

### CA04: Sign-In Risk Remediation (Behavioral Anomaly)

* **Target:** The authentication attempt (the journey).
* **Trigger:** The login originates from an anomalous context, such as a Tor exit node, known botnet IP, or impossible travel routing. The credentials may be valid, but the context is hostile.
* **Action:** Interrupt the authentication flow and enforce Multi-Factor Authentication (`builtInControls = "mfa"`).
* **Rationale:** Proves the human operating the keyboard is the legitimate identity owner, mitigating the risk of the specific session.

### CA05: User Risk Remediation (State Compromise)

* **Target:** The credential pair (the asset).
* **Trigger:** Microsoft Threat Intelligence detects the user's specific username and password hash circulating on dark web marketplaces.
* **Action:** Enforce MFA to prove identity, followed immediately by a mandatory password reset (`builtInControls = "mfa", "passwordChange"`).
* **Rationale:** The secret is burned. MFA alone is insufficient against a mathematically known password. The compromised credential must be destroyed and regenerated.

## 3. Infrastructure as Code (IaC) Payload

The following PowerShell payload utilizes the Microsoft Graph REST API v1.0.

**Operational constraints enforced in this script:**

1. **Strict Schema Compliance:** The Graph API requires exact key matches (e.g., `signInRiskLevels`, not `singInRiskLevels`).
2. **Break-Glass Exclusion:** The emergency access Object ID is explicitly excluded to prevent tenant lockout during false-positive risk events.
3. **Error Handling:** Try/Catch blocks are implemented to prevent silent pipeline failures.

```powershell
<#
.SYNOPSIS
    Deploys Risk-Based Conditional Access Policies (CA04 and CA05).

.DESCRIPTION
    CA04: Sign-in Risk Policy - Forces MFA for high-risk sign-in attempts (e.g., Anonymous IPs).
    CA05: User Risk Policy - Forces MFA and Password Reset for compromised identities.

.NOTES
    Tenant: <YOUR_TENANT_NAME>.onmicrosoft.com
    Permissions required: Policy.ReadWrite.ConditionalAccess
#>

# Step 1: Terminate existing sessions and authenticate to Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue 
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess" -TenantID "<YOUR_TENANT_NAME>.onmicrosoft.com"

# Global Emergency Access Account (Break-glass) to be excluded from all policies
$EmergencyAccessObjectId = "434cbc7f-ac65-4c0b-b274-c19952b06fa6"

# Step 2: Define CA04 parameters (Sign-in Risk)
Write-Host "Deploying CA04: Sign-in Risk Policy" -ForegroundColor Cyan
$SignInRiskParams = @{
    displayName = "CA04: Remediate High Sign-In Risk"
    state = "enabled"
    conditions = @{
        users = @{
            includeUsers = @("All")
            excludeUsers = @($EmergencyAccessObjectId)
        }
        applications = @{
            includeApplications = @("All")
        }
        signInRiskLevels = @("high")
    }
    grantControls = @{
        operator = "OR"
        builtInControls = @("mfa")
    }
}

# Step 3: Define CA05 parameters (User Risk)
Write-Host "Deploying CA05: Remediating User Risk" -ForegroundColor Cyan
$UserRiskParams = @{
    displayName = "CA05: Remediate High User Risk"
    state = "enabled"
    conditions = @{
        users = @{
            includeUsers = @("All")
            excludeUsers = @($EmergencyAccessObjectId)
        }
        applications = @{
            includeApplications = @("All")
        }
        userRiskLevels = @("high")
    }
    grantControls = @{
        operator = "AND"
        builtInControls = @("mfa", "passwordChange")
    }
}

# Step 4: Execute Deployment against Microsoft Graph
# --- Deployment for CA04 ---
try {
    $SignInPolicy = New-MgIdentityConditionalAccessPolicy -BodyParameter $SignInRiskParams -ErrorAction Stop
    Write-Host "SUCCESS: CA04 Sign-In Risk Deployed -> $($SignInPolicy.Id)" -ForegroundColor Green
} catch {
    Write-Host "FAILED TO DEPLOY CA04: $($_.Exception.Message)" -ForegroundColor Red
}

# --- Deployment for CA05 ---
try {
    $UserPolicy = New-MgIdentityConditionalAccessPolicy -BodyParameter $UserRiskParams -ErrorAction Stop
    Write-Host "SUCCESS: CA05 User Risk Deployed -> $($UserPolicy.Id)" -ForegroundColor Green
} catch {
    Write-Host "FAILED TO DEPLOY CA05: $($_.Exception.Message)" -ForegroundColor Red
}

```

## 4. Threat Simulation & Boundary Validation

Deployment of configuration is invalid without objective proof of enforcement. The following procedure was executed to validate the telemetry block.

1. **Vector Initiation:** Traffic was routed through the Tor Browser to mask the origin IP and simulate an anonymous, high-risk network.
2. **Authentication Attempt:** A login was initiated against `portal.azure.com` using standard Engineering User credentials.
3. **Telemetry Evaluation:** Entra ID Identity Protection flagged the authentication attempt as "High Risk" due to the anonymous IP address.
4. **Policy Enforcement:** CA04 successfully intercepted the request. The authentication flow was halted, and an MFA claim was demanded to prove the identity of the user, operating exactly as engineered.

## 5. End of Day Status

* **CA04:** Active and Verified.
* **CA05:** Active.
* **Zero-Trust Baseline:** Established.

