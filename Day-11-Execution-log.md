> **[SANITIZED ON 2026-07-05] SECURITY AUDIT:** Hardcoded tenant IDs, credentials, and user emails within this log have been replaced with generic placeholders for public release.

## Day 11: Session Governance & Legal Non-Repudiation

### 1. Objective

To eliminate the 90-day rolling session vulnerability by deploying **CA03: Session Governance**. The architecture required enforcing strict session token lifetimes and establishing legal non-repudiation before an access token is issued to any user.

**Success Criteria:** * Mathematically kill session tokens every 12 hours.

* Forbid persistent browser sessions.
* Force explicit, logged user agreement to a corporate IT policy (Terms of Use) as a mandatory grant control.

### 2. Execution Summary

The deployment was split between manual payload staging and Infrastructure as Code (IaC) policy execution.

1. **Payload Staging:** Created a dummy binary (`Fabrikam_IT_Policy.pdf`) to satisfy the Entra ID schema requirement. Uploaded the payload manually to Entra ID Terms of Use, enforcing document expansion to guarantee physical user interaction.
2. **Object Extraction:** Executed `Get-MgAgreement` via Microsoft Graph PowerShell to extract the unique GUID (`$ToU.Id`) of the staged payload.
3. **IaC Deployment:** Deployed the CA03 Conditional Access policy via `New-MgIdentityConditionalAccessPolicy`. The script targeted all users (excluding the Emergency Access Break-Glass account), targeted all applications, and bound the ToU GUID as a strict `grantControl`.
4. **Boundary Validation:** Tested the enforcement mechanism via an isolated InPrivate/Incognito session using standard user credentials (`a.rajavel`). Verified that Entra ID successfully interrupted the token issuance and mandated physical expansion and acceptance of the PDF.

### 3. Infrastructure as Code (IaC) Artifact

```powershell
<#
    Goal: 
        1) To extract the unique GUID of the ToU document
        2) To set a strict 12-hour session lifetime
#>

# Step-1: Connecting to the Microsoft Graph API
Disconnect-MgGraph -ErrorAction SilentlyContinue
Connect-MgGraph -Scopes "Agreement.Read.All", "Policy.ReadWrite.ConditionalAccess" -TenantId "<YOUR_TENANT_NAME>.onmicrosoft.com"

# Step-2: Fetch the Agreement ID for the Terms of Use (ToU) document
$ToU = Get-MgAgreement | Where-Object { $_.DisplayName -eq "Fabrikam Security Policy" }

if (-not $ToU) {
    Write-Host "ERROR: Terms of Use 'Fabrikam Security Policy' not found." -ForegroundColor Red
    return
}

Write-Host "ToU GUID: $($ToU.Id)" -ForegroundColor Cyan

# Step-03: Creating the Conditional Access Policy for Session Lifetime
Write-Host "Deploying CA03: Session Governance and ToU..." -ForegroundColor Cyan
$EmergencyAccessObjectId = "434cbc7f-ac65-4c0b-b274-c19952b06fa6"

$SessionPolicyParams = @{
    displayName = "CA03: Enforce ToU and 12-hour session lifetime"
    state = "enabled"
    conditions = @{
        users =@{
            includeUsers = @("All")
            excludeUsers = @($EmergencyAccessObjectId)
        }
        applications = @{
            includeApplications = @("All")
        }
    }
    grantControls = @{
        operator = "AND"
        termsOfUse = @($ToU.ID)
    }
    sessionControls = @{
        signInFrequency = @{
            value = 12
            type = "hours"
            isEnabled = $true
        }
        persistentBrowser = @{
            mode = "never"
            isEnabled = $true
        }
    }
}

try {
    $SessionPolicy = New-MgIdentityConditionalAccessPolicy -BodyParameter $SessionPolicyParams -ErrorAction Stop
    Write-Host "SUCCESS: CA03 Deployed -> $($SessionPolicy.Id)" -ForegroundColor Green
} catch {
    Write-Host "FAILED TO DEPLOY CA03: $($_.Exception.Message)" -ForegroundColor Red
}

```

### 4. Architectural Challenges & Failures

The deployment required multiple corrections due to syntax sloppiness and configuration drift.

* **Failure 1: Graph API Schema Violation (Grant Controls)**
* *The Error:* Attempted to map the ToU GUID to `CustomAuthenticationFactors`.
* *The Reality:* This array is strictly reserved for legacy third-party MFA providers (e.g., Duo). Agreement IDs must be mapped to the `termsOfUse` array. A failure to correct this would result in a rejected payload.


* **Failure 2: PowerShell Syntax and Variable Mismatches**
* *The Error:* Defined the payload as `$SessionPolicyParam` but called `$SessionPolicyParams` in the execution block. Guessed at Graph API parameters (`includeuser` instead of `includeUsers`, `unit = "hours"` instead of `type = "hours"`).
* *The Reality:* IaC requires absolute precision. A mismatched variable passes a null payload to the API. An invalid parameter key causes a hard script failure.


* **Failure 3: Configuration Drift (GUI)**
* *The Error:* Attempted to utilize the GUI to enforce the CA policy template and arbitrarily enabled 30-day consent expiration during the manual upload phase.
* *The Reality:* Deviating from the deployment mandate introduces scope creep. The goal was strictly IaC enforcement, not hybrid GUI/scripting deployment.


* **Failure 4: Device Registration Block (Per-Device Consent)**
* *The Error:* Left "Require users to consent on every device" toggled to **On** while testing in an isolated Incognito browser.
* *The Reality:* Per-device consent requires Entra ID to read the device state. An Incognito window strips device claims, causing Entra ID to throw a "You can't get there from here" block, entirely bypassing the PDF payload. This required a complete teardown and rebuild of the ToU object.
