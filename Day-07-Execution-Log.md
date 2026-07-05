## **Day 07: Infrastructure-as-Code & Identity Governance**

### **1. Executive Summary**

The objective was to eliminate manual provisioning and "privilege creep" by deploying a programmatic **Access Package** framework. This solution enables a "Request-Based" access model where users access resources via a self-service portal, subject to mandatory manager approval and automated lifecycle expiration.

### **2. Technical Architecture**

The deployment followed a three-tier hierarchy within Microsoft Entra ID, mimicking enterprise-grade IGA (Identity Governance and Administration) patterns:

| Layer | Component | Technical Detail |
| --- | --- | --- |
| **Container** | **Governance Catalog** | *Engineering Project Resource*: A logical boundary for delegation; functions similarly to Service Categories in OIM. |
| **Package** | **Access Package** | *Engineering Project Access*: The requestable "Product" containing specific resource roles. |
| **Resource** | **Security Group** | `SG-Project-Contributors`: An **Assigned** security group used as the target for the package. |

> **Design Note:** We strictly avoided Dynamic Groups for this implementation. Access Packages are designed for Requested Access (time-bound/discretionary), whereas Dynamic Groups are for Birthright Access (attribute-based).

---

### **3. Implementation Record (PowerShell)**

We utilized the **Microsoft Graph SDK** to ensure the environment is reproducible and version-controlled.

* **Core Modules:** `Microsoft.Graph.Identity.Governance`, `Microsoft.Graph.Groups`
* **Authentication Scopes:** `EntitlementManagement.ReadWrite.All`, `Group.ReadWrite.All`
* **Key Logic Update:**
* Shifted from explicit `Import-Module` to PowerShell Auto-loading to prevent manual load-order conflicts.
* Refactored parameters to align with the strict **Graph REST API schema**, specifically handling nested objects for Catalog identifiers.



---

### **4. Engineering Challenges & Resolutions**

#### **A. The .NET Assembly Collision (DLL Hell)**

* **Challenge:** Script crashed with a `Method 'GetTokenAsync' ... does not have an implementation` error.
* **Root Cause:** VS Code’s PowerShell Extension pre-loads older identity assemblies. When the Graph SDK attempted to load newer versions, a collision occurred.
* **Resolution:** Performed a "Hard Restart" of the IDE and explicitly imported the Authentication module to force the correct assembly load.

#### **B. The Identity Governance Licensing Paywall**

* **Challenge:** Attempting to add a **Directory Role (Security Reader)** to the Access Package triggered a licensing block.
* **Root Cause:** While Entra ID P2 covers basic Entitlement Management (Groups/Apps), bundling **Directory Roles** or **Azure Resources** requires the higher-tier *Microsoft Entra ID Governance* add-on license.
* **Resolution:** Pivoted the architecture. We used the Access Package to govern **Group Membership** only. The `Security Reader` role will instead be governed via **Privileged Identity Management (PIM)** on Day 10, maintaining Zero-Trust without the additional SKU cost.

#### **C. API Schema Mismatch (InvalidModel)**

* **Challenge:** API rejected requests with `400 BadRequest`.
* **Root Cause:** Cmdlets like `New-MgEntitlementManagementCatalog` are sensitive to specific string formats (e.g., the `State` parameter).
* **Resolution:** Stripped the payload to bare-minimum required attributes (`DisplayName`, `Description`) to ensure API acceptance.

---

### **5. Governance & Policy Configuration**

The "Brain" of the operation was configured with the following logic:

* **Requestor Scope:** Limited to internal directory users.
* **Approval Workflow:** Mandatory **Manager Approval** with a requirement for justification.
* **Lifecycle Management:** **90-Day Expiration.** Access is automatically revoked unless a re-extension is approved.

### **6. Security Impact**

* **Zero Standing Access:** Users no longer hold permanent memberships in sensitive project groups.
* **Audit Readiness:** Every grant has a documented requester, an approver, and a defined timestamp.
* **Operational Scale:** IT Admins are removed from the "Middle-man" role, allowing the governance engine to handle provisioning automatically.