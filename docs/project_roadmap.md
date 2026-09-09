# 6-Phase Implementation Roadmap

---

### Phase 1: Cloud Provisioning & Zero-Secret Setup
- **Goal**: Provision all Azure foundation resources and establish security permissions.
- **Tasks**:
  1. Create Resource Group: `rg-healthcare-migration-prod`.
  2. Provision ADLS Gen2 Storage Account with Hierarchical Namespace enabled.
  3. Create containers: `bronze`, `silver`, `gold`.
  4. Provision Azure Key Vault: `kv-healthcare-secrets-01`.
  5. Provision Azure Data Factory: `adf-healthcare-migration-01`.
  6. Enable ADF System-Assigned Managed Identity (SMI) and assign `Storage Blob Data Contributor` and `Key Vault Secrets User`.
  7. Connect ADF Git integration to GitHub repository `Azure-Healthcare-Data-Migration`.

---

### Phase 2: On-Prem Database & SHIR Gateway Setup
- **Goal**: Configure local EMR database and connect it to Azure without inbound firewall openings.
- **Tasks**:
  1. Create local PostgreSQL / SQL Server database `healthcare_emr_source`.
  2. Execute DDL and seed scripts for Patients, Providers, Encounters, Diagnoses, Claims.
  3. Create `etl_watermark_control` table and populate initial watermark values.
  4. Download and install Microsoft Integration Runtime (SHIR) on Windows.
  5. Register SHIR using ADF authentication key and verify connection.
  6. Store database credentials in Azure Key Vault.
  7. Create Key Vault and SHIR Linked Services in ADF.

---

### Phase 3: Metadata-Driven Watermark Ingestion (Bronze Layer)
- **Goal**: Build reusable, dynamic incremental ingestion pipeline.
- **Tasks**:
  1. Create ADF Pipeline: `pl_ingest_incremental_bronze`.
  2. Implement Lookup on `etl_watermark_control`.
  3. Implement Lookup for current max source timestamp.
  4. Build dynamic Copy Activity with parameterized SQL query.
  5. Sink data to ADLS Gen2 `bronze/` container as Parquet.
  6. Add Script/Stored Procedure activity to advance high-watermark timestamp.
  7. Test baseline full load and simulate incremental updates.

---

### Phase 4: Medallion Transformations & HIPAA Compliance (Silver & Gold)
- **Goal**: Clean data, mask PII, and build star schema marts using Mapping Data Flows.
- **Tasks**:
  1. Author Data Flow `df_bronze_to_silver`:
     - Clean data types, standardize dates, handle nulls.
     - Implement HIPAA SHA-256 masking on SSN and patient names.
     - Deduplicate records.
     - Sink clean Delta to `silver/`.
  2. Author Data Flow `df_silver_to_gold`:
     - Build `Dim_Patient`, `Dim_Provider`, `Dim_Diagnosis`, `Dim_Date`.
     - Build `Fact_Encounters` and `Fact_Claims`.
     - Sink conformed Delta files to `gold/`.

---

### Phase 5: Synapse Serverless Serving & Trigger Automation
- **Goal**: Provide instant SQL query access and schedule recurring runs.
- **Tasks**:
  1. Connect Azure Synapse Analytics Serverless SQL pool.
  2. Create database `HealthcareGoldAnalytics`.
  3. Create Views/External Tables over `gold/` Delta files.
  4. Create ADF Schedule Trigger for automated pipeline orchestration.
  5. Configure alert notifications for pipeline failures.

---

### Phase 6: Power BI Reporting & Portfolio Deliverables
- **Goal**: Deliver executive dashboards and document the project for CV/interviews.
- **Tasks**:
  1. Build Power BI Clinical & Financial Operations report.
  2. Document performance, security boundaries, and watermark algorithms.
  3. Prepare interview talking points and architectural defense presentation.
