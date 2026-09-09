# Technical Architecture Specification: Azure Healthcare Data Migration

---

## 1. Business Context & Objective
- **Organization**: Apex Regional Health System (Fictional Enterprise).
- **Core Challenge**: Legacy on-prem EMR database suffers from night-time query contention during financial reporting, lacks regulatory data masking for general analytics, and cannot scale for clinical ML models.
- **Solution**: Cloud data migration to an ADLS Gen2 Medallion Lakehouse powered by Azure Data Factory, Synapse Serverless SQL, and Power BI.

---

## 2. Core Entities & Schema Design

### On-Premises Source Tables
1. `patients` (`patient_id`, `first_name`, `last_name`, `ssn`, `dob`, `gender`, `address`, `city`, `state`, `zip`, `insurance_id`, `created_at`, `updated_at`)
2. `providers` (`provider_id`, `provider_name`, `specialty`, `department`, `npi_number`, `created_at`, `updated_at`)
3. `encounters` (`encounter_id`, `patient_id`, `provider_id`, `admission_date`, `discharge_date`, `encounter_type`, `department`, `discharge_disposition`, `created_at`, `updated_at`)
4. `diagnoses` (`diagnosis_id`, `encounter_id`, `icd10_code`, `diagnosis_description`, `is_primary`, `created_at`, `updated_at`)
5. `claims` (`claim_id`, `encounter_id`, `billed_amount`, `paid_amount`, `claim_status`, `denial_reason`, `submitted_date`, `paid_date`, `created_at`, `updated_at`)

### Watermark Control Table
```sql
CREATE TABLE etl_watermark_control (
    table_name VARCHAR(100) PRIMARY KEY,
    watermark_column VARCHAR(100),
    last_watermark_value TIMESTAMP,
    status VARCHAR(50),
    last_run_timestamp TIMESTAMP
);
```

---

## 3. HIPAA Security & PII Masking Architecture
- **In-Flight Encryption**: TLS 1.3 / HTTPS across SHIR gateway and Azure backplane.
- **At-Rest Encryption**: Azure Storage Service Encryption (SSE) with Microsoft-managed keys.
- **PII De-identification**: 
  - `ssn` -> Hashed via SHA-256 (`sha2(256, ssn)`).
  - `patient_name` -> Encrypted or pseudonymized into `patient_surrogate_key`.
  - Date of Birth -> Truncated to birth year or age bracket in Silver/Gold.

---

## 4. Medallion Layer Specifications

| Layer | Format | Partitioning | Cleaning & Transformation Rules |
| :--- | :--- | :--- | :--- |
| **Bronze** | Raw Parquet | `bronze/{table}/year={yyyy}/month={MM}/` | Raw append-only capture. Ingestion metadata added (`_ingestion_timestamp`, `_source_file`). |
| **Silver** | Delta / Clean Parquet | `silver/{table}/` | Schema enforcement, null value handling, SHA-256 PII masking, deduplication on primary keys. |
| **Gold** | Delta Star Schema | `gold/{dim_or_fact}/` | Conformed Dimensions (`Dim_Patient`, `Dim_Provider`, `Dim_Diagnosis`, `Dim_Date`) and Fact tables (`Fact_Encounters`, `Fact_Claims`). |

---

## 5. Budget & Cost Allocation ($200 Trial)
- Estimated monthly burn: **~$15 – $25**.
- Data Factory Mapping Data Flow compute: Set cluster Time-To-Live (TTL) to 10 minutes to eliminate idle cluster charges.
- Synapse Serverless SQL: Billed strictly on data scanned (~$5 per TB); our test datasets scan under 1 GB total (< $0.05).
