# Day 09 Documentation: Automated Access Reviews & Zero-Trust Enforcement

## 1. Executive Summary

The goal of Day 09 was to transition from manual, legacy "certification campaigns" (common in OIM) to a **fully automated Zero-Trust lifecycle** in Entra ID. We engineered a system that programmatically audits access to the `SG-Project-Contributors` group and terminates it if the user fails to provide a quarterly justification within 72 hours.

---

## 2. Architectural Pivot: Static vs. Dynamic

A critical technical distinction was made regarding the target group:

* **The Constraint**: You cannot reliably use Access Reviews to revoke access from **Dynamic Groups**.
* **The Reason**: If an Access Review denies a user in a dynamic group, the Entra ID backend will re-evaluate the user's attributes (e.g., `Department -eq 'Engineering'`) and immediately re-grant access.
* **The Solution**: We targeted the **Assigned (Static) Group** `SG-Project-Contributors` to ensure the "Deny" decision actually sticks and removes the user from the resource.

---

## 3. The Execution Script (`Day-09-Access-Review.ps1`)

The following PowerShell script was used to deploy the governance infrastructure via the Microsoft Graph API.

```powershell
<#
.SYNOPSIS
    Automates the creation of a quarterly access review for a specific Entra ID group.

.DESCRIPTION
    This script provisions an access review definition in Microsoft Entra ID (formerly Azure AD)
    for the 'SG-Project-Contributors' group. The access review is configured to run quarterly,
    requiring members to attest to their continued need for access. If a member does not respond
    within 3 days, their access will be automatically revoked (Zero-Trust principle).

.NOTES
    File Name: Day-09-Access-Review.ps1
    Permissions Required: AccessReview.ReadWrite.All (for creating access reviews)
    This script assumes an active Microsoft Graph session is already established or will prompt
    for authentication if none is found.
#>

# Step 1: Fetching the target group
# This section retrieves the Entra ID group for which the access review will be created.
Write-Host "Fetching target group: SG-Project-Contributors"
$Group = Get-MgGroup -Filter "Displayname eq 'SG-Project-Contributors'"

# If the target group is not found, the script will exit with an error.
if(-not $Group){
    Write-Host "Fatal ERROR: Target group 'SG-Project-Contributors' not found. Exiting script." -ForegroundColor Red
    return
}
else{
    Write-Host "Target group 'SG-Project-Contributors' found with ID: $($Group.Id)" -ForegroundColor Green
}

# Step 2: Define the Zero-Trust Payload
# This hash table defines the parameters for the access review, including its display name,
# description, scope, and automation settings.
$ReviewParams = @{
    displayName = "Project Contributors: Quarterly Access Attestation"
    descriptionForAdmins = "Automated Zero-Trust lifecycle management. Revokes access if ignored."
    descriptionForReviewers = "SECURITY AUDIT: Please attest to your continued need for access. If you do not respond, access is revoked automatically."
    
    # Scope: Defines who or what is being reviewed.
    # Here, it targets all transitive members (direct and nested) of the specified group.
    scope = @{
        "@odata.type" = "#microsoft.graph.accessReviewQueryScope"
        query = "/groups/$($Group.Id)/transitiveMembers"
        queryType = "MicrosoftGraph"
    }
 <#   
    # Reviewers: Defines who will perform the review.
    # The commented-out section below shows how to configure a self-review,
    # where each user reviews their own access.
    reviewers = @(
        # This query targets the subject (the user whose access is being reviewed).
        @{
            query = "/users/`$subject"
            queryType = "MicrosoftGraph"
        }
    )
#>
    # Automation Logic
    settings = @{
        mailNotificationsEnabled = $true
        reminderNotificationsEnabled = $true
        justificationRequiredOnApproval = $true
        autoApplyDecisionsEnabled = $true
        defaultDecisionEnabled = $true
        defaultDecision = "Deny" # THE KILL SWITCH
        instanceDurationInDays = 3
        
        # Schedule: Quarterly (Every 3 Months)
        recurrence = @{
            pattern = @{
                type = "absoluteMonthly"
                interval = 3
                dayOfMonth = 1
            }
            range = @{
                type = "noEnd"
                startDate = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
            }
        }
    }
}

# Step 3: Deploy to Graph API
try {
    Write-Host "Deploying Access Review via Graph API..." -ForegroundColor Cyan
    $Review = New-MgIdentityGovernanceAccessReviewDefinition -BodyParameter $ReviewParams -ErrorAction Stop
    Write-Host "SUCCESS: Access Review Provisioned. ID: $($Review.Id)" -ForegroundColor Green
} catch {
    Write-Host "DEPLOYMENT FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

```

---

## 4. Challenges & Technical Resolutions

| Challenge | Root Cause | Technical Resolution |
| --- | --- | --- |
| **CommandNotFoundException** | Terminal working directory was `C:\Users\kisho`, but the script was stored on the `D:` drive. | Used `cd` to change the directory context to the project root before execution. |
| **GUID Validation Failure** | Attempted to use `$subject` in the `reviewers` block. Graph API expected a literal 32-digit GUID. | **Implicit Self-Review**: Removed the `reviewers` block entirely. Entra ID defaults to self-review when the block is absent. |
| **OIM Mindset Lag** | Assuming an "Approver" was needed. | **Pivot to Self-Attestation**: Architected the review so the user is the primary actor, removing managerial bottlenecks. |

---

## 5. Final Verification (Portal Audit)

The following state was verified in the Entra ID Governance portal:

1. **Reviewers**: Successfully mapped to **Members (Self)**.
2. **Frequency**: Set to **Quarterly**.
3. **Default Action**: If no response is received within 3 days, the system executes **Remove access**.
4. **Provision ID**: `3b59593e-b9e2-4758-980e-dac28a85bd81`.

**Day 09 Result**: Standing privilege is now eradicated via automated, self-healing governance.