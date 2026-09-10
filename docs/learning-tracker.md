# Azure Healthcare Data Migration: Master Learning & Technical Tracker

Welcome to the authoritative engineering ledger for the **Azure Healthcare Data Migration & Medallion Lakehouse** platform. This document tracks all architectural concepts learned, technical interview question defenses, hands-on lab evidence, and troubleshooting playbooks.

---

## 1. Project Health & Progress Matrix

| Phase ID | Phase Name | Status | Tasks Complete | Score |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1** | **Cloud Provisioning & Zero-Secret Setup** | 🟢 **COMPLETED** | **7 / 7** | **10 / 10** |
| **Phase 2** | **On-Prem Database & SHIR Gateway Setup** | 🟢 **COMPLETED** | **7 / 7** | **10 / 10** |
| **Phase 3** | **Metadata-Driven Watermark Ingestion (Bronze)** | 🟡 **IN PROGRESS** | **0 / 7** | -- / 10 |
| **Phase 4** | **Medallion Transformations & HIPAA (Silver & Gold)** | 🔒 Locked | 0 / 7 | -- / 10 |
| **Phase 5** | **Synapse Serverless Serving & Trigger Automation** | 🔒 Locked | 0 / 5 | -- / 10 |
| **Phase 6** | **Power BI Reporting & CV Deliverables** | 🔒 Locked | 0 / 5 | -- / 10 |

---

## 2. Architectural Concepts Ledger (CL)

### [CL-01] ADLS Gen2 Hierarchical Namespace (HNS) vs Flat Blob Storage
- **Concept**: Azure Data Lake Storage Gen2 integrates the scalability of Blob storage with a true hierarchical file system.
- **Mechanism**:
  - In standard Blob Storage, "directories" are merely virtual key prefixes (`folder/subfolder/file.parquet`). Renaming a directory requires iterating over and copying every nested blob ($O(N)$ operations).
  - With **HNS enabled**, directories are first-class filesystem objects. Renaming or moving a directory is an atomic metadata operation ($O(1)$ constant time), regardless of directory size.
- **Lakehouse Impact**: Critical for ACID operations, Spark/Data Factory partitioning (`year=yyyy/month=MM/`), and Medallion directory maintenance without latency spikes.
- **Security**: Enables POSIX-compliant Access Control Lists (ACLs) down to directory and file levels in addition to Azure RBAC.

### [CL-02] Zero-Secret Architecture via Azure System-Assigned Managed Identity (SMI)
- **Concept**: Direct authentication between cloud services without secrets, passwords, or connection strings in code or configuration.
- **Mechanism**:
  - Enabling SMI on Azure Data Factory (`adf-healthcare-punit01`) creates a corresponding Service Principal inside Microsoft Entra ID (Azure AD).
  - Azure handles the underlying identity token lifecycle, automatic 4-hour key rotation, and cryptographic verification invisibly behind the scenes.
- **Healthcare / HIPAA Compliance**: Eliminates credential exposure risks, credential stuffing vulnerabilities, and accidental Git leaks of storage keys.

### [CL-03] Azure RBAC Data Plane vs Management Plane & Least Privilege
- **Concept**: Fine-grained role delegation dividing cloud management capabilities from data access capabilities.
- **Roles Applied**:
  - `Storage Blob Data Contributor`: Grants read, write, and delete permissions to blob data containers (`bronze`, `silver`, `gold`) without granting permission to alter storage account firewall settings or access keys.
  - `Key Vault Secrets User`: Grants ADF permission to read secret values (`secrets/get`, `secrets/list`) without allowing creation, editing, or deletion of keys and certificates.

### [CL-04] ADF Git Integration & Multi-Branch Enterprise CI/CD
- **Concept**: Direct source control linking between Data Factory Studio and GitHub repository `Azure-Healthcare-Data-Migration`.
- **Architecture**:
  - **Collaboration Branch (`main`)**: Stores live pipeline, dataset, and linked service JSON manifests under the root folder `/adf`.
  - **Publish Branch (`adf_publish`)**: ADF Studio automatically builds and commits fully parameterized ARM (Azure Resource Manager) templates here upon clicking "Publish".
  - **Benefits**: Enables pull request reviews, feature branching, code history rollbacks, and automated deployment pipelines via GitHub Actions or Azure DevOps.

### [CL-05] High-Watermark Metadata Pattern & State Management
- **Concept**: Incremental extraction pattern that pulls only new or modified rows since the previous execution without modifying source tables with database triggers.
- **Mechanism**:
  - Dedicated control table `etl_watermark_control` persists `table_name`, `watermark_column`, `last_watermark_value`, and execution metadata.
  - Pipeline extracts rows satisfying: `WHERE updated_at > @{activity('LookupOldWatermark').output.firstRow.last_watermark_value} AND updated_at <= @{activity('LookupNewWatermark').output.firstRow.max_timestamp}`.
  - Watermark table is strictly updated **after** the Copy Activity succeeds, ensuring idempotent failure recovery.

### [CL-06] Hybrid Cloud Connectivity via Self-Hosted Integration Runtime (SHIR)
- **Concept**: Secure bidirectional compute gateway bridging on-premise relational databases to Azure without public IPs or inbound firewall rules.
- **Mechanism**:
  - The SHIR agent installed on premise establishes an outbound-only, TLS 1.3 encrypted HTTPS connection over port 443 to Azure Data Factory service bus queues.
  - When ADF initiates a Copy pipeline, it queues an extraction task. The SHIR agent polls for work, queries the local database over loopback/LAN, compresses the data into Parquet, and streams it outbound to ADLS Gen2.

---

## 3. Technical Question & Defense Ledger (TQ)

### [TQ-01] Why use System-Assigned Managed Identity over Storage Account Access Keys or SAS tokens in enterprise healthcare migrations?
- **Candidate Defense**:
  > *"In a HIPAA-regulated healthcare environment, utilizing Account Keys is an unacceptable security hazard because they offer unfettered root-level access across the entire storage account with no expiration and no granular identity audit trail. SAS tokens, while time-limited, still require application-level secret management and manual rotation cycles.*
  > 
  > *By configuring Azure Data Factory with a System-Assigned Managed Identity (SMI) and assigning the `Storage Blob Data Contributor` RBAC role, we implement a true Zero-Secret architecture. Entra ID manages token acquisition, rotation, and lifecycle tied directly to the resource itself. Every single data access request is attributed to the ADF service principal in Azure Monitor and diagnostic audit logs, satisfying HIPAA auditability requirements."*

### [TQ-02] Why is Hierarchical Namespace (HNS) mandatory for ADLS Gen2 in Medallion Lakehouse architectures instead of standard Blob Storage?
- **Candidate Defense**:
  > *"In a standard Azure Blob storage container, directories do not physically exist; they are simply character prefixes in the object URL. In a Medallion Lakehouse where data flows write atomic partitioned batches (e.g., `bronze/encounters/year=2026/month=09/`), moving or renaming a folder in flat storage forces the engine to issue individual copy-and-delete operations for every single blob ($O(N)$ operations).*
  > 
  > *ADLS Gen2 with Hierarchical Namespace (HNS) provides a true POSIX filesystem. Directory renames are atomic metadata updates executed in $O(1)$ constant time, drastically reducing pipeline duration and compute costs. Furthermore, HNS allows fine-grained POSIX access control lists (ACLs) to be inherited down folder hierarchies, enabling defense-in-depth access governance."*

### [TQ-03] How does a Self-Hosted Integration Runtime (SHIR) securely bridge on-premise databases without opening inbound firewall ports?
- **Candidate Defense**:
  > *"Corporate infosec and HIPAA compliance strictly forbid opening inbound ports through enterprise firewalls into on-premise clinical networks. Microsoft SHIR overcomes this by operating entirely on an **outbound-only polling model**.*
  > 
  > *The SHIR daemon initiates outbound HTTPS connections on port 443 over TLS 1.3 to Azure Data Factory. When a pipeline runs, ADF posts an execution payload to a private control queue. The on-premise agent pulls the task, queries the internal SQL Server over local LAN, packages the payload into Parquet, and streams it directly to ADLS Gen2 over outbound HTTPS. At no point is the local network reachable from the public internet."*

### [TQ-04] How do you prevent data loss or duplicate ingestion if an incremental pipeline fails halfway through a run?
- **Candidate Defense**:
  > *"We enforce strict pipeline idempotency through a two-phase watermark pattern. In the first phase, we capture the static maximum source timestamp into an ADF pipeline variable before starting the copy. In the second phase, the Copy Activity sinks the data to partitioned Bronze storage.*
  > 
  > *Crucially, the stored procedure that updates `etl_watermark_control` runs **only upon successful completion** of the Copy Activity. If the pipeline crashes mid-stream, the watermark in the database remains unchanged. The subsequent run re-evaluates the same delta window, avoiding silent data loss. Any overlapping records are seamlessly deduplicated in the Silver transformation layer."*

---

## 4. Troubleshooting Playbooks & Incident RCA

| Incident ID | Phase | Problem Encountered | Root Cause | Resolution |
| :--- | :--- | :--- | :--- | :--- |
| **INC-01** | Phase 2 | `sys.server_logins` invalid object during service user creation | SQL Server system view is `sys.server_principals` | Updated DDL script to check `sys.server_principals` and re-executed idempotently. |

---

## 5. Lab Evidence & Configuration Artifacts

### Phase 1 Provisioned Resources (Active Cloud Topology)
- **Subscription**: Azure Sponsorship / Free Trial
- **Resource Group**: `rg-healthcare-migration-prod` (Central India)
- **Storage Account**: `sthealthcarelake01` (StorageV2, Hierarchical Namespace Enabled)
  - Containers: `bronze`, `silver`, `gold`
- **Key Vault**: `kv-healthcare-sec01` (Azure RBAC Permission Model)
- **Data Factory**: `adf-healthcare-punit01` (Version 2)
  - Managed Identity Principal ID: Assigned
  - Role Assignment 1: `Storage Blob Data Contributor` on `sthealthcarelake01`
  - Role Assignment 2: `Key Vault Secrets User` on `kv-healthcare-sec01`
  - Git Integration: Connected to `punitgiri921/Azure-Healthcare-Data-Migration` (Root: `/adf`, Collaboration Branch: `main`, Publish Branch: `adf_publish`)

### Phase 2 Provisioned Local Source Artifacts
- **Database Engine**: Microsoft SQL Server 2022 Express (`.\SQLEXPRESS`)
- **Database Name**: `healthcare_emr_source`
- **Clinical & Financial Tables Created**:
  - `dbo.providers`: 10 rows
  - `dbo.patients`: 20 rows (synthetic PII for Silver masking)
  - `dbo.encounters`: 15 rows
  - `dbo.diagnoses`: 17 rows (ICD-10 clinical diagnoses)
  - `dbo.claims`: 15 rows (billing, denial codes, settlements)
- **Watermark Control**: `dbo.etl_watermark_control` (5 entities initialized to `1970-01-01 00:00:00`)
- **Service Account**: `adf_svc_user` created with `db_datareader` and `db_datawriter` roles.
