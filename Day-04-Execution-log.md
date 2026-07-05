> **[SANITIZED ON 2026-07-05] SECURITY AUDIT:** Hardcoded tenant IDs, credentials, and user emails within this log have been replaced with generic placeholders for public release.

# Technical Runbook: Day 04 - Dynamic Identity Governance & License Automation
**Execution Date:** May 4, 2026
**Target Environment:** Microsoft Entra ID (M365 E5 Developer / Entra ID P2 Sandbox)
**Objective:** Decouple identity lifecycle management from manual provisioning through attribute-based Dynamic Security Groups and Group-Based Licensing (GBL).

## 1. Environment Preparation & Bug Remediation
Prior to executing the Graph API calls, the local engineering environment required reconfiguration to bypass known Windows execution and token-caching bugs.

*   **Execution Policy Override:** Bypassed local system restrictions preventing `.ps1` execution.
    *   `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`
*   **Web Account Manager (WAM) Token Poisoning:** Microsoft Graph module threw a null pointer exception (`Object reference not set to an instance of an object`) due to WAM intercepting the enterprise device-code handshake.
    *   *Resolution:* Permanently disabled WAM integration for the module and forced direct tenant authentication.
    *   `Set-MgGraphOption -DisableLoginByWAM $true`
    *   `Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.ReadWrite.All", "Directory.ReadWrite.All" -TenantId "<YOUR_TENANT_NAME>.onmicrosoft.com"`

## 2. Infrastructure Deployment: Dynamic Security Groups
Provisioned three distinct Security Groups relying on the Entra ID backend processing engine to evaluate membership dynamically based on the `user.department` attribute.

*   **Script Executed:** `Day-04-Dynamic-Group-Creation.ps1`
*   **Cmdlet Used:** `New-MgGroup`
*   **Target Groups & Logic:**
    *   `SG-Engineering-Users` -> `(user.department -eq "Engineering")`
    *   `SG-HR-Users` -> `(user.department -eq "HR")`
    *   `SG-ITSupport-Users` -> `(user.department -eq "IT Support")`
*   **Result:** Backend engine successfully parsed the Day 03 user ingestion data and automatically populated the groups within 15 minutes.

## 3. License Automation: Group-Based Licensing (GBL)
To ensure all users fall under the Zero-Trust and Privileged Identity Management (PIM) architecture planned for Weeks 3 and 4, the Entra ID Premium P2 license was bound to the logical groups rather than individual users.

*   **Script Executed:** `Day-04-License-Binding.ps1`
*   **License Identification:** Extracted the underlying `SkuId` for `AAD_PREMIUM_P2` (`84a661c4-e949-4bd2-a560-ed7766fcaf2b`) via `Get-MgSubscribedSku`.
*   **Cmdlet Used:** `Set-MgGroupLicense`
*   **Result:** P2 licenses successfully inherited by all members of the three dynamic groups. `ConsumedUnits` validated at 15.

## 4. Lifecycle Validation: The Mover Scenario
Executed a programmatic identity state change to verify the robustness of the dynamic governance rules. 

*   **Script Executed:** `Day-04-Mover-Test.ps1`
*   **Action:** Isolated user 'Akshitha Rajavel' (Engineering). Modified the `Department` attribute to `HR` via `Update-MgUser`.
*   **Validation:** 
    1.  User was automatically stripped from `SG-Engineering-Users`.
    2.  User was automatically ingested into `SG-HR-Users`.
    3.  P2 License inheritance recalculated and maintained seamlessly.
*   **Conclusion:** The identity infrastructure is now resilient to manual human error and automated based on the source-of-truth metadata.

***
