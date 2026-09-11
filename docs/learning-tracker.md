# Azure Healthcare Data Migration: Master Engineering & Learning Tracker

Welcome to the authoritative engineering ledger for the **Azure Healthcare Data Migration & Medallion Lakehouse** platform. This document tracks all architectural concepts learned, technical interview question defenses, hands-on lab evidence, and troubleshooting playbooks in strict accordance with our **Permanent Learning Rules**.

---

## 1. Project Health & Progress Matrix

| Phase ID | Phase Name | Status | Tasks Complete | Phase Gate Stage (11 Steps) | Score |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Phase 1** | **Cloud Provisioning & Zero-Secret Setup** | 🟢 **COMPLETED** | **7 / 7** | **10. PHASE COMPLETE** | **10 / 10** |
| **Phase 2** | **On-Prem Database & SHIR Gateway Setup** | 🟢 **COMPLETED** | **7 / 7** | **10. PHASE COMPLETE** | **10 / 10** |
| **Phase 3** | **Metadata-Driven Watermark Ingestion (Bronze)** | 🟢 **COMPLETED** | **8 / 8** | **10. PHASE COMPLETE** | **10 / 10** |
| **Phase 4** | **Medallion Transformations & HIPAA (Silver & Gold)** | 🟡 **IN PROGRESS** | **0 / 6** | **1. UNDERSTAND** | -- / 10 |
| **Phase 5** | **Synapse Serverless Serving & Trigger Automation** | 🔒 Locked | 0 / 5 | Locked | -- / 10 |
| **Phase 6** | **Power BI Reporting & CV Deliverables** | 🔒 Locked | 0 / 5 | Locked | -- / 10 |

```text
11-STEP PHASE GATE PIPELINE:
[UNDERSTAND (Phase 4 Active)] -> EXPLAIN BACK -> PLAN -> YOU EXECUTE -> PROVIDE EVIDENCE 
           -> TECH QUESTIONS -> EVALUATION -> FIX GAPS -> ARCH RECAP -> PHASE COMPLETE -> UNLOCK NEXT
```

---

## 2. Final "AHA!" Breakthrough Principles (Rule 26)

1. **SHIR is the secure bridge** between my private SQL Server and Azure. It polls outbound on port 443; no ports are ever opened inbound.
2. **ADF orchestrates the pipeline**; it manages the schedule and coordinates data movement, but it is NOT the database or compute warehouse.
3. **Key Vault protects secrets**; it secures database credentials, but it never holds or transfers healthcare data rows.
4. **Managed Identity lets Azure talk to Azure** without storing passwords or storage access keys in code or pipeline JSON.
5. **Git tracks pipeline definitions and code changes**, while data-history mechanisms (Watermarks / CDC) track changes to the actual healthcare data rows.

---

## 3. "Why We Built This" Enterprise Architecture Matrix (Rule 18 & 9)

| Component | Real-World Problem | Why We Need It | What It Technically Does | What Happens Without It? (Negative Analysis) |
| :--- | :--- | :--- | :--- | :--- |
| **SQL Server** | Hospital clinical records reside on private internal database servers. | Simulate production hospital EMR environment. | Houses transactional tables (Patients, Encounters, Diagnoses, Claims). | ❌ No source dataset to migrate or simulate enterprise workloads. |
| **SHIR Gateway** | Azure cannot directly reach internal private IP addresses or corporate LANs. | Provide secure, outbound-only enterprise bridge without exposing firewall. | Runs Windows daemon (`DIAHostService`), polls ADF for tasks, queries SQL locally. | ❌ Would force opening inbound firewall ports to public internet (fatal HIPAA violation). |
| **Key Vault** | Database passwords stored in configuration or code leak into GitHub. | Centralized, hardware-grade secret management with access audit logs. | Stores `sql-onprem-password` as an encrypted secret, read dynamically at runtime. | ❌ Database credentials stored in plaintext in git-tracked JSON files. |
| **Managed Identity** | Services authenticating to cloud storage require managing shared keys or certificates. | Enforce Zero-Secret enterprise architecture with automatic token rotation. | ADF service principal authenticates directly against Microsoft Entra ID. | ❌ Must use root Storage Account Keys; compromises entire lakehouse if leaked. |
| **ADF** | Data movement from on-prem to cloud needs automated scheduling, retry logic, and monitoring. | Serverless enterprise ETL/ELT pipeline orchestration. | Executes Lookup, Copy, and Stored Procedure activities across hybrid environments. | ❌ Manual Python scripts running on cron with no retry, telemetry, or monitoring. |
| **Watermark Control** | Extracting entire multi-million row tables daily causes huge egress bills and CPU spikes. | Enable idempotent incremental delta loading. | Tracks `last_watermark_timestamp` in `dbo.etl_watermark_control`. | ❌ ADF re-extracts 100% of rows every run; exploding compute, storage, and egress bills. |
| **ADLS Gen2 (HNS)** | Standard cloud storage performs poorly when renaming or partitioning massive directories. | Scalable, POSIX-compliant lakehouse storage layer. | Enables atomic $O(1)$ directory moves and fine-grained security ACLs. | ❌ Slow $O(N)$ blob copy operations on directory moves, blocking lakehouse pipeline writes. |
| **Bronze Container** | Transformed data can be corrupted by faulty business logic or schema changes. | Immutable raw data landing zone for disaster recovery and audits. | Stores raw uncompressed/Parquet payloads exactly as extracted from source. | ❌ Cannot replay or reprocess historical raw data if downstream cleansing logic bugs out. |
| **Silver Container** | Raw clinical data contains patient PII (SSN, Phone, Email) violating HIPAA. | Cleanse, standardize, deduplicate, and mask sensitive health identifiers. | Stores SHA-256 masked identities with normalized clinical lookup codes. | ❌ Data analysts and data scientists have direct access to plaintext patient PII (HIPAA fine). |
| **Gold Container** | Normalized 3NF relational schemas result in slow, complex analytical queries in BI. | Deliver high-speed Star Schema dimensional models for executive reporting. | Houses `Fact_Clinical_Encounters` and conforming dimension tables. | ❌ Power BI reports must execute complex multi-table joins across raw layers, stalling dashboards. |
| **GitHub Integration** | Pipeline changes made directly in cloud UI risk untracked outages or collisions. | Infrastructure-as-Code (IaC), peer review, and automated CI/CD deployment. | Commits pipeline JSONs to `main` and exports ARM templates to `adf_publish`. | ❌ No version history, no rollback capability, accidental edits deployed immediately to prod. |

---

## 4. Concept Disambiguation Matrix (Rule 11)

| Construct | Primary Responsibility | What It NEVER Does |
| :--- | :--- | :--- |
| **GitHub** | Tracks and versions **pipeline JSON definitions, linked services, and ARM templates**. | Never holds, processes, or versions clinical data rows. |
| **Watermark Control** | Tracks **state of data extraction** (`last_watermark_timestamp`). | Does not track row-level deletions or individual column mutation history. |
| **CDC / Change Tracking** | Logs **row-level DML mutations** (INSERT, UPDATE, DELETE) inside the SQL database engine. | Does not orchestrate data movement or move files to the cloud. |
| **Bronze / Silver / Gold** | Progressive **cleansing, de-identification (HIPAA), and dimensional modeling** of analytical data. | Does not replace source transactional OLTP databases. |

---

## 5. Architectural Concepts Ledger (CL) — 3-Tier Depth (Rule 5)

### [CL-01] ADLS Gen2 Hierarchical Namespace (HNS) vs Flat Blob Storage
- **Level 1 — Simple Intuition**: Flat storage pretends folders exist by putting slashes in file names. HNS creates real physical file cabinets and directories.
- **Level 2 — Technical Mechanics**: ADLS Gen2 HNS implements POSIX-compliant directory trees. Renaming a directory updates an internal inode pointer in constant time $O(1)$ rather than copying thousands of individual blobs ($O(N)$).
- **Level 3 — Senior Enterprise Architecture**: Critical for Spark/Data Flow partition commits (`year=yyyy/month=MM/`). Without HNS, distributed writes experience massive latency and partial file write risks during folder commit phases. Enables POSIX-compliant ACLs down to directory and file levels in addition to Azure RBAC.

### [CL-02] Zero-Secret Architecture via Azure System-Assigned Managed Identity (SMI)
- **Level 1 — Simple Intuition**: Instead of giving ADF a physical password or API key to Azure Storage, Azure recognizes ADF by its own facial recognition / passport.
- **Level 2 — Technical Mechanics**: Enabling SMI on Azure Data Factory (`adf-healthcare-punit01`) creates a corresponding Service Principal inside Microsoft Entra ID (Azure AD). Azure handles the underlying identity token lifecycle, automatic 4-hour key rotation, and cryptographic verification invisibly behind the scenes.
- **Level 3 — Senior Enterprise Architecture**: Complies with HIPAA § 164.312(d). Eliminates credential exposure risks, credential stuffing vulnerabilities, and accidental Git leaks of storage keys. Logs individual service principal IDs in Azure Monitor for non-repudiation audits.

### [CL-03] Azure RBAC Data Plane vs Management Plane & Least Privilege
- **Level 1 — Simple Intuition**: Separating the keys to the front door of the building (management) from the keys to read documents in the filing cabinet (data plane).
- **Level 2 — Technical Mechanics**: 
  - `Storage Blob Data Contributor`: Grants read, write, and delete permissions to blob data containers (`bronze`, `silver`, `gold`) without granting permission to alter storage account firewall settings or access keys.
  - `Key Vault Secrets User`: Grants ADF permission to read secret values (`secrets/get`, `secrets/list`) without allowing creation, editing, or deletion of keys and certificates.
- **Level 3 — Senior Enterprise Architecture**: Adheres to zero-trust least-privilege architecture. Even if an ADF pipeline identity is somehow hijacked, the attacker cannot delete the storage account or change firewall rules.

### [CL-04] ADF Git Integration & Multi-Branch Enterprise CI/CD
- **Level 1 — Simple Intuition**: A shared notebook where developers make rough drafts on one page, and an editor only prints the clean final version to the official book when approved.
- **Level 2 — Technical Mechanics**: Linking ADF Studio to GitHub repo with collaboration branch (`main`), root directory (`/adf`), and automated ARM template publishing branch (`adf_publish`).
- **Level 3 — Senior Enterprise Architecture**: Enables pull request reviews, feature branching, code history rollbacks, and automated deployment pipelines via GitHub Actions or Azure DevOps without manual portal configuration in production environments.

### [CL-05] High-Watermark Metadata Pattern & State Management
- **Level 1 — Simple Intuition**: Bookmarking where you stopped reading so tomorrow you only read new pages instead of starting from page 1 every single morning.
- **Level 2 — Technical Mechanics**: Dedicated control table `etl_watermark_control` tracks `table_name`, `watermark_column`, `last_watermark_value`. Pipeline extracts rows `WHERE updated_at > LastWatermark AND updated_at <= MaxSourceTimestamp` and updates the watermark only upon successful Copy completion.
- **Level 3 — Senior Enterprise Architecture**: Guarantees pipeline idempotency. If network drops mid-stream during a 50GB extract, the watermark never updates. The next run gracefully retries the exact same window with zero silent record drop.

### [CL-06] Hybrid Cloud Connectivity via Self-Hosted Integration Runtime (SHIR)
- **Level 1 — Simple Intuition**: Instead of letting outsiders knock on your hospital door, a dedicated courier inside steps outside to check the cloud mailbox for work orders.
- **Level 2 — Technical Mechanics**: Windows daemon `DIAHostService` initiates outbound HTTPS calls on TCP port 443 over TLS 1.3 to ADF service bus queues. It pulls the query instruction, queries `localhost:1433`, compresses data into Parquet, and streams it straight to ADLS Gen2.
- **Level 3 — Senior Enterprise Architecture**: Zero attack surface on enterprise firewalls. Eliminates costly dedicated ExpressRoute VPN requirements for initial data migration batches while maintaining strict network perimeter isolation.

### [CL-07] Dynamic SQL Expressions & Parameterized Watermark Injection
- **Level 1 — Simple Intuition**: Generating a customized search instruction on the fly using exact start and stop timestamps so only the new batch is pulled.
- **Level 2 — Technical Mechanics**: ADF Copy Activity uses string interpolation:
  `@concat('SELECT * FROM dbo.encounters WHERE updated_at > ''', activity('LookupOldWatermark').output.firstRow.last_watermark_value, ''' AND updated_at <= ''', activity('LookupNewWatermark').output.firstRow.new_watermark, '''')`.
- **Level 3 — Senior Enterprise Architecture**: Evaluates dynamic bounds entirely in-memory within ADF orchestration, preventing hardcoded dates in pipelines. Ensures strict boundary isolation where late-arriving records during active copy executions are deferred to subsequent schedules.

### [CL-08] Atomic Watermark Advancement via Stored Procedures & Transaction Scope
- **Level 1 — Simple Intuition**: Moving the bookmark forward only AFTER you close the book and put it back on the shelf, never while reading.
- **Level 2 — Technical Mechanics**: Stored Procedure `dbo.usp_update_watermark` is triggered conditionally upon `CopyIncrementalEncounters` returning status `Succeeded`. It updates `last_watermark_value` and `last_run_timestamp` in a single ACID transaction.
- **Level 3 — Senior Enterprise Architecture**: Solves distributed two-phase commit risks. If ADF loses connectivity to Azure Data Lake midway through blob writes, the stored procedure is never reached, guaranteeing that pipeline retries cleanly re-extract the identical batch without silent data loss.

### [CL-09] Bronze Lakehouse Storage & Parquet Snappy Compression
- **Level 1 — Simple Intuition**: Storing medical notes in a locked filing cabinet in their original handwriting, but zipped up tight to save drawer space.
- **Level 2 — Technical Mechanics**: Relational rows are serialized into Apache Parquet with Snappy compression directly on the SHIR agent node and streamed to `sthealthcarelake01/bronze/`.
- **Level 3 — Senior Enterprise Architecture**: Columnar storage enables dictionary encoding, run-length compression, and fast column pruning for downstream Spark engines. Parquet preserves raw data types (dates, decimals, strings) without CSV parsing errors or floating-point truncation.

---

## 6. Technical Question & Defense Ledger (TQ) — Evaluated Rubric (Rule 14 & 15)

### [TQ-01] Why use System-Assigned Managed Identity over Storage Account Access Keys or SAS tokens in enterprise healthcare migrations?
- **Rating**: 🟢 **Correct** (Senior Architect Level)
- **Candidate Defense**:
  > *"In a HIPAA-regulated healthcare environment, utilizing Account Keys is an unacceptable security hazard because they offer unfettered root-level access across the entire storage account with no expiration and no granular identity audit trail. SAS tokens, while time-limited, still require application-level secret management and manual rotation cycles.*
  > 
  > *By configuring Azure Data Factory with a System-Assigned Managed Identity (SMI) and assigning the `Storage Blob Data Contributor` RBAC role, we implement a true Zero-Secret architecture. Entra ID manages token acquisition, rotation, and lifecycle tied directly to the resource itself. Every single data access request is attributed to the ADF service principal in Azure Monitor and diagnostic audit logs, satisfying HIPAA auditability requirements."*

### [TQ-02] Why is Hierarchical Namespace (HNS) mandatory for ADLS Gen2 in Medallion Lakehouse architectures instead of standard Blob Storage?
- **Rating**: 🟢 **Correct** (Senior Architect Level)
- **Candidate Defense**:
  > *"In a standard Azure Blob storage container, directories do not physically exist; they are simply character prefixes in the object URL. In a Medallion Lakehouse where data flows write atomic partitioned batches (e.g., `bronze/encounters/year=2026/month=09/`), moving or renaming a folder in flat storage forces the engine to issue individual copy-and-delete operations for every single blob ($O(N)$ operations).*
  > 
  > *ADLS Gen2 with Hierarchical Namespace (HNS) provides a true POSIX filesystem. Directory renames are atomic metadata updates executed in $O(1)$ constant time, drastically reducing pipeline duration and compute costs. Furthermore, HNS allows fine-grained POSIX access control lists (ACLs) to be inherited down folder hierarchies, enabling defense-in-depth access governance."*

### [TQ-03] How does a Self-Hosted Integration Runtime (SHIR) securely bridge on-premise databases without opening inbound firewall ports?
- **Rating**: 🟢 **Correct** (Senior Architect Level)
- **Candidate Defense**:
  > *"Corporate infosec and HIPAA compliance strictly forbid opening inbound ports through enterprise firewalls into on-premise clinical networks. Microsoft SHIR overcomes this by operating entirely on an **outbound-only polling model**.*
  > 
  > *The SHIR daemon initiates outbound HTTPS connections on port 443 over TLS 1.3 to Azure Data Factory. When a pipeline runs, ADF posts an execution payload to a private control queue. The on-premise agent pulls the task, queries the internal SQL Server over local LAN, packages the payload into Parquet, and streams it directly to ADLS Gen2 over outbound HTTPS. At no point is the local network reachable from the public internet."*

### [TQ-04] How do you prevent data loss or duplicate ingestion if an incremental pipeline fails halfway through a run?
- **Rating**: 🟢 **Correct** (Senior Architect Level)
- **Candidate Defense**:
  > *"We enforce strict pipeline idempotency through a two-phase watermark pattern. In the first phase, we capture the static maximum source timestamp into an ADF pipeline variable before starting the copy. In the second phase, the Copy Activity sinks the data to partitioned Bronze storage.*
  > 
  > *Crucially, the stored procedure that updates `etl_watermark_control` runs **only upon successful completion** of the Copy Activity. If the pipeline crashes mid-stream, the watermark in the database remains unchanged. The subsequent run re-evaluates the same delta window, avoiding silent data loss. Any overlapping records are seamlessly deduplicated in the Silver transformation layer."*

### [TQ-05] How does the upper watermark boundary enforce snapshot isolation if new rows arrive during an active Copy Activity?
- **Rating**: 🟢 **Correct** (Senior Architect Level)
- **Candidate Defense**:
  > *"Because our pipeline explicitly binds the extraction query with an upper bound `updated_at <= NewWatermark`, any emergency admissions or clinical orders posted while the Copy Activity is actively streaming are excluded from the current batch. When the stored procedure executes, it advances the watermark strictly to that locked `NewWatermark` value.*
  > 
  > *On the subsequent pipeline run, the lower bound becomes `updated_at > OldWatermark` (which equals the previous `NewWatermark`), ensuring that all records inserted during or after that execution window are seamlessly captured without data loss or race conditions."*

### [TQ-06] Where does compute and data serialization occur during on-premise to cloud data ingestion via SHIR?
- **Rating**: 🟢 **Correct** (Senior Architect Level)
- **Candidate Defense**:
  > *"ADF does not reach into the on-premises network to pull rows. The Self-Hosted Integration Runtime operates entirely on the local machine within the hospital network. It executes the SQL query over local ODBC/TCP, reads the rows, serializes them in-memory into Snappy Parquet format, and pushes the compressed payload out over HTTPS 443 to the ADLS Gen2 DFS endpoint.*
  > 
  > *This distinction is critical because it preserves the internal security boundary: SQL Server remains completely unexposed to the public internet, no inbound firewall ports are opened, and CPU-intensive Parquet compression is distributed to the edge."*

---

## 7. Failure Engineering & Resilience Scenarios (Rule 19)

| Scenario | What Detects It? | What Fails? | What Data Is Affected? | Recovery Blueprint |
| :--- | :--- | :--- | :--- | :--- |
| **SHIR Service Stops / Reboots** | ADF Pipeline Monitor throws heartbeat timeout (>3 min). | Copy activities fail immediately with connection refused. | None. Source SQL transaction closes cleanly; no partial files committed. | Run PowerShell: `Start-Service DIAHostService`. Configure Windows service recovery to auto-restart. |
| **Pipeline Fails Mid-Stream (e.g. at 600K of 1M rows)** | Copy Activity throws `SocketTimeoutException` in ADF Monitor. | Downstream Stored Procedure activity does NOT execute. | Orphaned partial Parquet partition in Bronze. Watermark table remains at old timestamp. | Sinking with partition overwrite or date folder wipes partials; re-run automatically re-evaluates the full delta window safely. |
| **Database Password Rotated on SQL Server** | SHIR throws SQL Login Failed (Error 18456) when testing Linked Service. | All pipelines referencing `ls_sqlserver_onprem`. | Ingestion halts; source data remains intact in SQL Server. | Add new version of secret `sql-onprem-password` in Key Vault. Zero ADF pipeline code change required! |
| **Watermark Table Set Ahead of Source Data (e.g. Year 2099)** | Pipeline runs succeed in 2 seconds but 0 rows read / 0 rows written. | Silent delta ingestion gap; new clinical encounters are ignored. | Bronze stops receiving any updates. | Execute manual `UPDATE dbo.etl_watermark_control` to reset timestamp back to last verified load date. |

---

## 8. Lab Evidence & Configuration Artifacts

### Phase 1 Provisioned Resources (Active Cloud Topology)
- **Subscription**: Azure Free Trial / Sponsorship
- **Resource Group**: `rg-healthcare-migration-prod` (Central India)
- **Storage Account**: `sthealthcarelake01` (StorageV2, Hierarchical Namespace Enabled)
  - Containers: `bronze`, `silver`, `gold`
- **Key Vault**: `kv-healthcare-sec01` (Azure RBAC Permission Model)
- **Data Factory**: `adf-healthcare-punit01` (Version 2)
  - Managed Identity: Assigned
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
- **SHIR Registered**: `shir-onprem-gateway-01` (Node: `DESKTOP-H5RKB3H`, Daemon: `DIAHostService`, Status: Online)
- **ADF Linked Services**:
  - `ls_keyvault_healthcare`: Connected to `kv-healthcare-sec01`
  - `ls_sqlserver_onprem`: Connected to `healthcare_emr_source` via SHIR using password from Key Vault

### Phase 3 Provisioned Lakehouse Ingestion Artifacts
- **ADLS Gen2 Linked Service**: `ls_adls_healthcare` (Authentication: System-Assigned Managed Identity)
- **ADF Datasets Created**:
  - `ds_sql_encounters`: Source table pointer
  - `ds_sql_watermark_control`: State engine pointer
  - `ds_adls_bronze_parquet`: Parquet sink in `bronze` container (Compression: Snappy)
- **SQL Stored Procedure**: [sql/04_create_watermark_stored_procedure.sql](file:///d:/01_Ex_Files_Intermediate_SQL_for_Data_Scientists/Goodly%20PowerBi/Azure-Healthcare-Data-Migration/sql/04_create_watermark_stored_procedure.sql) (`dbo.usp_update_watermark`)
- **Incremental Pipeline**: [adf/pipeline/pl_ingest_incremental_bronze.json](file:///d:/01_Ex_Files_Intermediate_SQL_for_Data_Scientists/Goodly%20PowerBi/Azure-Healthcare-Data-Migration/adf/pipeline/pl_ingest_incremental_bronze.json) (4/4 Activities Succeeded)
- **Verified Extraction**: Exactly 15 encounter rows extracted and written to `sthealthcarelake01/bronze/encounters/`
- **Advanced State**: `dbo.etl_watermark_control` for `encounters` updated to `2024-02-23 15:30:00.000` (Status: `SUCCESS`)
- **Architectural Reference Blueprint**: [docs/phase3_watermark_architecture.drawio](file:///d:/01_Ex_Files_Intermediate_SQL_for_Data_Scientists/Goodly%20PowerBi/Azure-Healthcare-Data-Migration/docs/phase3_watermark_architecture.drawio)
- **Technical Walkthrough**: [docs/phase3_walkthrough.md](file:///d:/01_Ex_Files_Intermediate_SQL_for_Data_Scientists/Goodly%20PowerBi/Azure-Healthcare-Data-Migration/docs/phase3_walkthrough.md)
