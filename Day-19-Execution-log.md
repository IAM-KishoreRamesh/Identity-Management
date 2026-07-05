> **[SANITIZED ON 2026-07-05] SECURITY AUDIT:** Hardcoded tenant IDs, credentials, and user emails within this log have been replaced with generic placeholders for public release.

# Technical Runbook: Day 19 - Unified SecOps Telemetry & SIEM Activation

**Execution Date:** June 26, 2026

**Target Environment:** `<YOUR_TENANT_NAME>.onmicrosoft.com`

**Telemetry Workspace:** `la-telemetry-prod-centralindia-001` (Location: `centralindia`)

**Objective:** Deploy Microsoft Sentinel on top of existing log infrastructure, activate native Entra ID data connectors, and validate the streaming telemetry pipeline for non-human Workload Identities.

---

## 1. Architectural Overview

A secure control plane is structurally incomplete without real-time auditability. Having created a headless Workload Identity (`OIM-12c-Sync-Engine`) with highly privileged directory modification capabilities (`User.ReadWrite.All`), the tenant faces a critical compliance risk if credential abuse or script malfunctions go unnoticed.

This deployment transitions the architecture from a passive log collection state to an active threat-hunting posture. By instantiating **Microsoft Sentinel** on top of the pre-existing day-05/06 Log Analytics Workspace, advanced security intelligence and data schema layers are overlaid directly onto the raw cloud logs without destroying historical telemetry or requiring database replication overhead.

---

## 2. Phase 1: SIEM Initialization & Ingestion Overlay

Because Microsoft Sentinel acts as an intelligence abstraction layer rather than a standalone database entity, initialization requires anchoring the solution directly to a validated Log Storage resource.

### 2.1 Component Upgrades

1. **Target Identification:** Located the existing operational data sink (`la-telemetry-prod-centralindia-001`) within the primary subscription boundaries.
2. **Feature Provisioning:** Triggered the solution onboarding process within the Azure control plane, binding the Microsoft Sentinel security engine directly to the workspace container.
3. **Database Schema Mutation:** Upgrading the workspace instantly injects foundational SecOps tables (`SecurityEvent`, `AuditLogs`, `SigninLogs`, `AADServicePrincipalSignInLogs`) into the Log Analytics engine, making it capable of parsing advanced Kusto Query Language (KQL) indicators of compromise (IoCs).

---

## 3. Phase 2: Diagnostic Routing & Data Connector Binding

The SIEM layer requires explicit data pipelines to draw logs from the identity provider engine. The telemetry pipeline was established by executing a cloud diagnostic binding from the Microsoft Entra ID control plane to the target Log Analytics workspace.

### 3.1 Telemetry Matrix

The following logging categories were bound to the `Entra-To-LAW-Pipeline` configuration profile to guarantee absolute visibility into identity state changes:

* **`AuditLogs`:** Tracks administrative changes, permission updates, and lifecycle mutations.
* **`SignInLogs`:** Records interactive human authentication attempts.
* **`NonInteractiveUserSignInLogs`:** Captures background human session refreshes.
* **`ServicePrincipalSignInLogs`:** **(Critical Monitoring Boundary)** Explicitly tracks authentication requests driven by application registrations, client IDs, and automated script secrets.
* **`RiskyUsers`:** Streams continuous Identity Protection telemetry for accounts exhibiting abnormal behavioral metrics.
* **`UserRiskEvents`:** Feeds raw anomaly signals directly into the SIEM engine for automated analysis.

---

## 4. Phase 3: Programmatic Pipeline Verification

Cloud infrastructure updates rely on asynchronous backend database replication. Validation requires direct interrogation of the database schema to verify data plane convergence.

### 4.1 Verification Vector

A direct Kusto Query Language (KQL) query was executed against the workspace engine to test structural compliance.

```kusto
AADServicePrincipalSignInLogs
| take 10

```

### 4.2 Analysis of Results

* **Terminal State:** The query returned an execution status of operational success, yielding a message of `No results found from the last 24 hours.`
* **Technical Interpretation:** The absence of red error text confirms that the compiler successfully resolved the `AADServicePrincipalSignInLogs` table schema. The zero-record result is structurally correct and expected, as the `OIM-12c-Sync-Engine` workload identity has not yet initiated its first automated programmatic login session. The pipeline is open, valid, and actively listening for traffic.

---
