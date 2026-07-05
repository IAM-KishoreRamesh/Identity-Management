# [SANITIZED ON 2026-07-05] SECURITY AUDIT: Hardcoded tenant IDs, credentials, and user emails replaced with generic placeholders for public repo.
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

#Step-03: Creating the Conditional Access Policy for Session Lifetime
Write-Host "Deploying CA03: Session Governance and ToU..." -ForegroundColor Cyan
$EmergencyAccessObjectId = "78051c4c-5704-492f-a583-03cf8a41a35c"

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
