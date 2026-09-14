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

### Phase 3: Metadata-Driven Lakehouse Ingestion (Bronze Layer)
- **Goal**: Dynamically extract on-prem SQL tables into ADLS Gen2 `bronze/` container as timestamped Parquet files.
- **Tasks & Architecture**:
  1. Generic Source Dataset: `DS_SQL_Source` with parameter `p_table_name`.
  2. Generic Sink Dataset: `DS_ADLS_Bronze` with parameters `p_folder_name` and `p_file_name`.
  3. Master Ingestion Pipeline: `PL_Ingest_Bronze`:
     - Lookup `LKP_Get_Watermark_Control`: Reads active watermark control metadata (`WHERE status = 'SUCCESS'`).
     - ForEach Loop `FE_Table_Load`: Iterates through tables sequentially (`isSequential = true`).
     - Dynamic Upper Watermark: `LKP_Current_Watermark` extracts snapshot `MAX(watermark_column)`.
     - Incremental Copy Activity: `COPY_SQL_To_Bronze` streams delta records with timestamped filename `@concat(item().table_name, '_', formatDateTime(utcNow(),'yyyyMMddHHmmss'), '.parquet')`.
  4. Watermark Closure: Add stored procedure activity (`usp_update_watermark`) to advance `last_watermark_value`.

---

### Phase 4: Medallion Transformations & HIPAA Compliance (Silver & Gold)
- **Goal**: Clean data, mask PII/PHI under HIPAA Safe Harbor, and build star schema dimensional models using Mapping Data Flows.
- **Stage A (Patients Bronze to Silver Transformation)**:
  1. Author & Configure Mapping Data Flow `DF_Patients_Bronze_To_Silver`:
     - Source: `SrcBronzePatients` reading from `patients/*.parquet`.
     - Derived Column `DrvMaskPHI`:
       - First Name: Initial masked (`concat(substring(first_name,1,1),'***')`).
       - Last Name: Initial masked (`concat(substring(last_name,1,1),'*')`).
       - SSN: HIPAA cryptographic hash (`sha2(256,replace(ssn,'-',''))`).
     - Sink: `SNKSilverPatients` writing to `DS_ADLS_Silver_Patients` (`silver/patients/`) with schema validation.
  2. Author Orchestration Pipeline `PL_Bronze_To_Silver` to execute `DF_Patients_Bronze_To_Silver` on Azure IR (8 cores General compute).
  3. Validate Silver output and verify de-identification compliance.
- **Stage B (Silver to Gold Dimensional Modeling)**:
  4. Author `DF_Patients_Silver_To_Gold`:
     - Add `surrogateKey()` transformation (`patient_sk`).
     - Calculate patient `age` from `dob`.
     - Sink conformed dimension table to `gold/dim_patient/`.
  5. Clean and process remaining entities (`encounters`, `providers`, `diagnoses`, `claims`) into Star Schema marts (`Dim_Provider`, `Dim_Diagnosis`, `Fact_Encounters`).


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
