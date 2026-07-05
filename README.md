# 🛡️ Azure Governance Framework: Identity Management

Welcome to the **Identity Management** repository. This project is a hands-on, practical runbook designed to eradicate theoretical knowledge by building and breaking Microsoft Entra ID through live attack simulations. 

It serves as a comprehensive architecture lab in preparation for the **SC-300 (Microsoft Identity and Access Administrator)** exam, transitioning a tenant from a legacy state to a programmatic, Zero-Trust environment.

---

## 🎯 Phase 1 Objectives & Achievements

### Week 1–2: Attack Surface Discovery
* **Simulated Attacks:** Triggered Entra ID Protection alerts via Anonymous IP / Tor browser attack simulations.
* **Geographic Testing:** Triggered "Impossible Travel" alerts using VPN location switching.
* **Zero-Trust Baseline:** Deployed and tested Conditional Access policies (MFA enforcement, compliant device requirements, and session frequency limits).
* **Just-In-Time Access:** Configured Privileged Identity Management (PIM) with Global Admin, Security Admin, and User Administrator set as eligible roles.
* **API Automation:** Validated Microsoft Graph PowerShell commands to disable users, revoke sessions, and read risky user data.
* **App Registrations:** Created Application Registrations with specific Graph API permissions configured.

### Week 3: Conditional Access Hardening
* **Policy Architecture:** Built Conditional Access policies explicitly blocking anonymous IP and impossible travel.
* **Phishing Resistance:** Implemented phishing-resistant MFA for all risky sign-ins.
* **Device Posture:** Tested and enforced "compliant device" requirements.
* **Session Control:** Configured strict sign-in frequency controls (e.g., 12-hour re-authentication for privileged roles and mandatory Terms of Use acceptance).

### Week 4: Access Reviews & Entitlement Management
* **Non-Human Identities:** Created a Workload Identity (Service Principal) for secure, machine-to-machine Authentication (AUTH) and Authorization (AUTZ) purposes.
* **Access Reviews:** Configured recurring reviews for Azure AD role assignments, guest user reviews with auto-removal, and group membership reviews leveraging manager attestation.
* **Entitlement Management:** Built Access Packages for project onboarding, configured multi-stage approval workflows, tested B2B connected organization scenarios, and implemented strict expiration and renewal policies.

---

## 🏗️ Architectural Engineering Highlights

Throughout the 20-day deployment, several enterprise-grade engineering practices were enforced:

* **Infrastructure as Code (IaC):** Strict segregation of duties was enforced. The Data Plane (Identity) was managed via **Microsoft Graph PowerShell**, while the Control Plane (Log Analytics / Telemetry) was provisioned using **Azure Bicep**.
* **Zero Standing Access:** "Click-Ops" and permanent administrative assignments were eradicated. Security Groups were converted to **Privileged Access Groups** (PIM for Groups) ensuring a 100% Just-In-Time (JIT) access model.
* **Automated Identity Teardown:** Engineered a programmatic "Kill Sequence" that severs license inheritance, ejects users from dynamic groups, and revokes session tokens the moment a user's department attribute shifts to "Terminated."
* **Advanced Troubleshooting:** Documented and resolved complex deployment blockers, including `.NET` assembly collisions (`TypeLoadException`) between Azure modules, Graph API truncation bugs, and B2B inheritance lockouts.

---

## 📂 Repository Structure

This repository is structured sequentially across 20 days. Each `Day-XX` file represents a specific phase of the architecture rollout:

*   **`.ps1` (PowerShell Scripts):** The Microsoft Graph API and Azure PowerShell scripts used to execute the configurations.
*   **`.bicep` (Infrastructure as Code):** Declarative files used to deploy underlying Azure SecOps telemetry infrastructure.
*   **`.md` (Execution Logs):** Detailed daily runbooks documenting the objective, bugs remediated, scripts executed, and validation results.

### 📖 Daily Execution Logs
* [Day 04 Execution Log](./Day-04-Execution-log.md)
* [Day 05 Execution Log](./Day-05-Execution-log.md)
* [Day 06 Execution Log](./Day-06-Execution-log.md)
* [Day 07 Execution Log](./Day-07-Execution-Log.md)
* [Day 08 Execution Log](./Day-08-Execution-log.md)
* [Day 09 Execution Log](./Day-09-Execution-log.md)
* [Day 10 Execution Log](./Day-10-Execution-log.md)
* [Day 11 Execution Log](./Day-11-Execution-log.md)
* [Day 12 Execution Log](./Day-12-Execution-log.md)
* [Day 13 Execution Log](./Day-13-Execution-log.md)
* [Day 14 Execution Log](./Day-14-Execution-log.md)
* [Day 15 Execution Log](./Day-15-Execution-Log.md)
* [Day 16 Execution Log](./Day-16-Execution-log.md)
* [Day 17 Execution Log](./Day-17-Execution-log.md)
* [Day 18 Execution Log](./Day-18-Execution-log.md)
* [Day 19 Execution Log](./Day-19-Execution-log.md)
* [Day 20 Execution Log](./Day-20-Execution-log.md)

---

> *"Identity is the new security perimeter."*
