# [SANITIZED ON 2026-07-05] SECURITY AUDIT: Hardcoded tenant IDs, credentials, and user emails replaced with generic placeholders for public repo.
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
# Step-1: Connect to Entra ID using Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess" -TenantID "<YOUR_TENANT_NAME>.onmicrosoft.com"

#Reference to create condtional access policy: https://learn.microsoft.com/en-us/graph/api/conditionalaccessroot-list-policies?view=graph-rest-1.0&tabs=powershell

#Step-2: Create CA04: Sign-in Risk Policy
Write-Host "Deploying CA04: Sign-in Risk Policy"
# Global Emergency Access Account (Break-glass) to be excluded from all policies
$EmergencyAccessObjectId = "d4a8d9f5-a056-4dd8-b081-dab89a9d45d8"

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

#Step-3: Create CA05: User Risk (Password Reset Enforcement)
Write-Host "Deploying CA05: Remediating User Risk"
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

