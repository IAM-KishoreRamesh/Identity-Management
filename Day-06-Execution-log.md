> **[SANITIZED ON 2026-07-05] SECURITY AUDIT:** Hardcoded tenant IDs, credentials, and user emails within this log have been replaced with generic placeholders for public release.

# Technical Architecture Document: Day 06

**Phase:** 1 (The Foundation)
**Module:** Telemetry & Security Operations (SecOps) Initialization
**Date Executed:** May 7, 2026

## 1. Executive Summary

Prior to this deployment, the Entra ID tenant operated without persistent telemetry. Any administrative changes, role escalations, or authentication attempts were transient and un-auditable historically.

Day 06 established the **Telemetry Pipeline**, bridging the Identity Data Plane with the Azure Infrastructure Control Plane. This ensures all critical security events are permanently recorded, queryable via Kusto Query Language (KQL), and ready for future integration with Microsoft Sentinel (Phase 3).

Additionally, a strict **Segregation of Duties (SOD)** was enforced for all future deployments:

* **Data Plane (Identity/Access):** Managed strictly via PowerShell / Microsoft Graph API.
* **Control Plane (Infrastructure):** Managed strictly via declarative Bicep templates executed via Azure CLI.

---

## 2. Infrastructure Deployment (The Control Plane)

The storage container (Log Analytics Workspace) was provisioned using Infrastructure as Code (IaC) to ensure idempotency and standardization.

### 2.1 The Bicep Definition (`Day-06-Telemetry.bicep`)

This file defines the exact state of the Log Analytics Workspace, utilizing the free-tier compliant 30-day retention policy to prevent accidental billing.

```bicep
@description ('Deployment location')
param location string = 'centralindia'

@description ('Standardized tags for resource governance')
param tags object = {
    Environment: 'Prod'
    Project: 'Telemetry'
}

@description('Name of Log Analytics Workspace')
param workspaceName string = 'la-telemetry-prod-centralindia-001'

@description ('Data retention in days for Log Analytics Workspace')
param dataRetention int = 30

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
    name: workspaceName
    location: location
    tags: tags
    properties: {
        sku: {
            name: 'PerGB2018'
        }
        retentionInDays: dataRetention
    }
}

output workspaceResourceId string = logAnalyticsWorkspace.id

```

### 2.2 Execution Pipeline (Azure CLI)

The deployment was executed via the Azure CLI to avoid legacy PowerShell .NET assembly conflicts (`TypeLoadException`).

```bash
# 1. Authenticate to the Azure Tenant
az login --tenant <YOUR_TENANT_NAME>.onmicrosoft.com

# 2. Provision the Resource Group Container
az group create --name "rg-telemetry-prod-centralindia-001" --location "centralindia"

# 3. Deploy the Bicep Template into the Resource Group
az deployment group create --resource-group "rg-telemetry-prod-centralindia-001" --template-file "D:\Azure\Azure Governance Framework\Identity-Management\Day-06-Telemetry.bicep"

```

---

## 3. The Identity Bridge (The Data Plane)

To route the logs from the Identity provider (Entra ID) to the Infrastructure container (Azure LAW), a Diagnostic Setting was created via Entra ID.

*Note: Due to known propagation delays with the `microsoft.insights` provider in the Graph API Beta endpoint on newly created subscriptions, this initial binding was executed manually in the Azure Portal to guarantee a successful handshake.*

**Configuration Specifications:**

* **Setting Name:** `Entra-To-LAW-Pipeline`
* **Target Workspace:** `la-telemetry-prod-centralindia-001`
* **Routed Tables:**
* `AuditLogs` (Tracks directory changes, group creations, role assignments)
* `SignInLogs` (Tracks interactive user authentications)
* `NonInteractiveUserSignInLogs` (Tracks background token refreshes)
* `ServicePrincipalSignInLogs` (Tracks programmatic/app authentications)



---

## 4. Verification & KQL Telemetry

Validation was performed using Kusto Query Language (KQL) directly in the Log Analytics Workspace to confirm the SLA propagation delay had cleared and data was actively indexing.

### 4.1 Administrative Telemetry Validation

This query tracks modifications to the tenant architecture, ensuring the Zero-Trust RBAC boundaries remain untampered.

```kusto
AuditLogs
| project TimeGenerated, OperationName, Result
| order by TimeGenerated desc
| take 10
// Expected Output: "Update user - success", "Add member to group - success", etc.

```

---

## 6. Challenges & Remediations

During the Day 06 execution, several architectural and environmental blockers were encountered. Each was mitigated using standard DevSecOps principles.

### 6.1 Environmental Challenge: The Licensing Expiration Pivot

**The Blocker:** The underlying Entra ID P2 trial powering the Zero-Trust architecture is set to expire in 30 days. Furthermore, Microsoft recently disabled the free 25-seat E5 licenses for standard M365 Developer sandboxes, removing the fallback option for the upcoming SC-300 labs.
**The Remediation (Disposable Infrastructure):** A strategic pivot was made to embrace a "Disposable Tenant" model. By hardcoding all Day 03, 04, and 05 Identity configurations into PowerShell/Graph scripts, the architecture is no longer bound to the current trial. On May 29, a fresh tenant and trial will be spun up, and the entire infrastructure will be re-deployed in minutes via code to support Phase 2.

### 6.2 Code Architecture Challenge: Bicep Scope Violations

**The Blocker:** An attempt was made to define both a Subscription-scoped resource (Resource Group) and a ResourceGroup-scoped resource (Log Analytics Workspace) within a single, non-modular Bicep template. The Bicep compiler strictly forbids this without the use of modules.
**The Remediation (SOD Refinement):** Rather than overengineering a multi-file modular structure for a single resource, the Segregation of Duties (SOD) was redefined:

* The Container (Resource Group) is provisioned imperatively via Azure CLI.
* The Infrastructure (Workspace) is provisioned declaratively via Bicep.

### 6.3 Local Tooling Challenge: .NET Assembly Collision (`TypeLoadException`)

**The Blocker:** Attempting to authenticate via Azure PowerShell (`Connect-AzAccount`) resulted in a severe `TypeLoadException`. The VS Code integrated terminal had locked legacy .NET assemblies into memory, causing a conflict between the outdated `AzureRM` framework and the modern `Az` module.
**The Remediation (Tooling Pivot):** Rather than performing a destructive purge of the local PowerShell environment, the execution tool was swapped to the **Azure CLI** (`az login`, `az deployment`). This bypassed the .NET assembly lock entirely while still executing the exact same Bicep Control Plane code.

### 6.4 Telemetry Challenge: Asynchronous Schema Initialization

**The Blocker:** Following the successful configuration of the Entra ID Diagnostic Settings, initial Kusto Query Language (KQL) queries against the `SignInLogs` table failed with a *Failed to resolve table expression* error.
**The Remediation:** Diagnosed as a standard Azure "Day 0" behavior. Log Analytics Workspaces do not pre-provision empty tables; schemas are generated dynamically *only upon the first successful data ingestion*. Artificial authentication failures were triggered via an Incognito window, and upon the clearing of the 15-minute Azure SLA propagation delay, the table materialized and data was successfully queried.
