> **[SANITIZED ON 2026-07-05] SECURITY AUDIT:** Hardcoded tenant IDs, credentials, and user emails within this log have been replaced with generic placeholders for public release.

# Technical Runbook: Day 20 - Capstone Validation & Headless Automation

**Execution Date:** June 26, 2026

**Target Environment:** `<YOUR_TENANT_NAME>.onmicrosoft.com`

**Target Identity:** `<TARGET_USER>@<YOUR_TENANT_NAME>.onmicrosoft.com`

**Objective:** Execute an automated identity lifecycle event (account termination) utilizing a Zero-Trust Workload Identity, bypassing human MFA requirements, and verifying the action via centralized SIEM telemetry.

## 1. Architectural Overview

The Capstone objective validates the Phase 2 Identity Synchronization pipeline. Legacy on-premises HR systems (simulated via local JSON state) often lack native Entra ID integration. To prevent authorization creep and synchronization delays, a programmatic bridge is required to terminate cloud access the moment an on-premises termination is flagged.

This execution utilizes the `OIM-12c-Sync-Engine` service principal provisioned on Day 17 and scoped with the `User.ReadWrite.All` application permission on Day 18.

## 2. Phase 1: The Automation Engine (Python & MSAL)

The synchronization engine was constructed in Python, leveraging the Microsoft Authentication Library (MSAL) to acquire an OAuth 2.0 access token via the Client Credentials flow.

### 2.1 Credential Injection & Authentication

The script was configured with the tenant's exact endpoints and the vaulted Client Secret.

*Initial Execution Error:* The engine initially failed with an `AADSTS7000215: Invalid client secret provided` error.
*Root Cause & Remediation:* The public 'Secret ID' was mistakenly passed instead of the cryptographic 'Secret Value'. Once the string was replaced with the actual vault key (`L-78Q~...`), the MSAL engine successfully acquired the machine token.

### 2.2 The Graph API Payload

Upon reading the `Terminated` status from the local `OIM_Export_State.json` file, the script constructed and fired a `PATCH` request to the Microsoft Graph API.

```python
# The payload explicitly disables the target account without deleting it
payload = {"accountEnabled": False}
graph_url = f"https://graph.microsoft.com/v1.0/users/{target_upn}"
response = requests.patch(graph_url, headers=headers, json=payload)

```

## 3. Phase 2: Boundary and Telemetry Verification

To ensure the architecture meets enterprise auditing standards, two separate verification layers were queried.

### 3.1 Physical State Verification (Control Plane)

Navigated to the Entra ID administration portal and inspected the target user (`<TARGET_USER>@<YOUR_TENANT_NAME>.onmicrosoft.com`).

* **Result:** The Account Status attribute was verified as **Disabled**. The Graph API successfully mutated the directory state without human interaction.

### 3.2 SecOps Telemetry Verification (Data Plane)

To satisfy security and compliance requirements, the action had to be provably logged by the Microsoft Sentinel SIEM deployed on Day 19.

A Kusto Query Language (KQL) hunt was executed against the Sentinel Log Analytics Workspace:

```kusto
AADServicePrincipalSignInLogs
| take 10

```

* **Result:** The query successfully returned the Service Principal sign-in telemetry. The log table explicitly tracked the initial authentication failure (ResultType: `7000215`) followed by the successful headless authentications (ResultType: `0`), validating that the SIEM is actively monitoring all non-human identity traffic.

**Status:** The Capstone is complete. The Zero-Trust Identity API Bridge is fully functional and secure.

---
