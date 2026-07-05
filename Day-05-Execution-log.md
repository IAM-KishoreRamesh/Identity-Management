# Technical Runbook: Day 05 - Entra ID Role-Based Access Control & Boundary Validation
**Execution Date:** May 5, 2026
**Target Environment:** Microsoft Entra ID (M365 E5 Developer Sandbox)

## Objective
Transition from a binary Global Administrator model to a Zero-Trust tiering model by enforcing the Principle of Least Privilege (PoLP) using the Microsoft Graph API.

## 1. Directory Role Provisioning
Leveraged the `Microsoft.Graph.Identity.Governance` module to assign built-in directory roles to dynamic group members. 
*   **Script Executed:** `Day-05-RBAC-Assignment.ps1`
*   **Authentication Context:** Delegated token via `Connect-MgGraph` bound explicitly to the enterprise tenant.
*   **Assignments:**
    *   `SG-ITSupport-Users` (Target: Khiran Josphe) -> Assigned **Helpdesk Administrator**.
    *   `SG-Engineering-Users` (Target: Harish Ramu) -> Assigned **Security Reader**.

## 2. Boundary Testing & Privilege Escalation Mitigation
Executed targeted validation tests using an isolated browser session under the Helpdesk Administrator context.

*   **Anti-Privilege Escalation Triggered:** Attempted to reset the password of Harish Ramu (Security Reader). The Entra ID backend actively blocked the request. This confirms Microsoft's hardcoded safeguard preventing lower-tier admins from hijacking the credentials of other administrators.
*   **Positive Test:** Successfully reset the password for Akshitha Rajavel (Standard User / 0 Assigned Roles).
*   **Negative Test:** Attempted to delete the `SG-Engineering-Users` dynamic security group. The UI proactively disabled the deletion controls, confirming the RBAC boundary holds against destructive actions.

## Conclusion
The Identity Data Plane is now strictly governed. Administrative sprawl has been neutralized.