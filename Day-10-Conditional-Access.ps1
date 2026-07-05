<#
    Goal: To set up the conditional access policy for MFA on Global Admins and helpdesk Admins
    and to block apps that don't support modern authentication.
#>

Write-Host "Deploying Zero-Trust Conditional Access Baseline..." -Foreground Cyan

# ID for the 'Break-Glass' account to prevent accidental lockout during policy enforcement
$EmergencyAccessObjectId = "78051c4c-5704-492f-a583-03cf8a41a35c"

# Policy-1: Block Legacy Authentication Tenant-Wide
# Legacy protocols (POP, IMAP, SMTP, etc.) do not support MFA and are common targets for spray attacks.
$LegacyAuthParams = @{
    displayName = "CA01: Block Legacy Authentication"
    state       = "enabled" 
    conditions = @{
        users = @{ #Frontend UI: Assignments > Users and groups
            includeUsers = @("All")
            excludeUsers = @($EmergencyAccessObjectId)
        }
        applications = @{
            includeApplications = @("All") 
        }
        # Target legacy authentication protocols specifically
        clientAppTypes = @("exchangeActiveSync", "other") 
    }
    grantControls = @{ #Frontend UI: Access controls > Grant
        operator = "OR" 
        builtInControls = @("block")
    }
}

# Role IDs for Global Administrator and Helpdesk Administrator respectively
$DirectoryRoleIds = @( 
    "62e90394-69f5-4237-9190-012177145e10", # Global Administrator
    "729827e3-9c14-49f7-bb1b-9608f156bbb8"  # Helpdesk Administrator
)

# Policy-2: Require MFA for privileged administrative roles
# Ensures that high-privilege accounts must pass an MFA challenge regardless of location.
$MfaAdminParams = @{
    displayName = "CA02: Require MFA for Administrators" #Frontend UI: Name
    state       = "enabled" #Frontend UI: Enable policy
    conditions = @{
        users = @{ #Frontend UI: Assignments > Users and groups
            # Target specific directory roles rather than individual user IDs
            includeRoles = $DirectoryRoleIds
            excludeUsers = @($EmergencyAccessObjectId)
        }
        applications = @{ 
            includeApplications = @("All") 
        }
    }
    grantControls = @{ #Frontend UI: Access controls > Grant
        operator = "OR" 
        builtInControls = @("mfa") #Policy UI: Access controls > Grant > Require multi-factor authentication
    }
}

# 4. EXECUTION BLOCK
Write-Host "Deploying Policies to Directory Edge..." -ForegroundColor Yellow

try {
    $LegacyPolicy = New-MgIdentityConditionalAccessPolicy -BodyParameter $LegacyAuthParams -ErrorAction Stop
    Write-Host "[SUCCESS] CA01: Legacy Auth Block Deployed -> $($LegacyPolicy.Id)" -ForegroundColor Green
} catch {
    Write-Host "[FAILED] CA01: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    $MfaPolicy = New-MgIdentityConditionalAccessPolicy -BodyParameter $MfaAdminParams -ErrorAction Stop
    Write-Host "[SUCCESS] CA02: Admin MFA Enforcement Deployed -> $($MfaPolicy.Id)" -ForegroundColor Green
} catch {
    Write-Host "[FAILED] CA02: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Cutover execution complete. Verify in Entra ID Portal." -ForegroundColor Cyan