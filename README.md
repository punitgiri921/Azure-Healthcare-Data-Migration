# Azure Healthcare Data Migration & Medallion Lakehouse

[![Azure Data Factory](https://img.shields.io/badge/Azure%20Data%20Factory-v2%20Orchestrator-0078D4?logo=azuredatafactory&logoColor=white)](adf/)
[![Azure Data Lake Gen2](https://img.shields.io/badge/ADLS%20Gen2-Hierarchical%20Namespace-008272?logo=microsoftazure&logoColor=white)](docs/architecture_spec.md)
[![Azure Synapse Analytics](https://img.shields.io/badge/Synapse-Serverless%20SQL%20Pools-0078D7?logo=azuredevops&logoColor=white)](sql/)
[![Power BI](https://img.shields.io/badge/Power%20BI-Healthcare%20Analytics-F2C811?logo=powerbi&logoColor=black)](docs/)
[![HIPAA Compliance](https://img.shields.io/badge/Security-HIPAA%20%2F%20SHA--256%20PII%20Masking-success)](docs/architecture_spec.md#hipaa-security--pii-masking)
[![Self-Hosted IR](https://img.shields.io/badge/Gateway-Self--Hosted%20IR%20(SHIR)-blueviolet)](docs/project_roadmap.md#phase-2-on-premise-emr-database--shir-gateway-setup)

---

## Executive Summary

**Azure Healthcare Data Migration & Medallion Lakehouse** is an enterprise-grade cloud data engineering reference architecture. Designed to showcase production-level data engineering, cloud networking, and security governance, this project migrates a legacy on-premises **Electronic Medical Records (EMR) & Revenue Cycle Management (RCM)** system into a modern **Azure Data Lake Storage Gen2 (ADLS Gen2)** Medallion architecture.

This solution demonstrates how modern data organizations eliminate on-prem legacy database bottlenecks, enforce strict **HIPAA compliance and PII data masking**, automate **metadata-driven watermark incremental delta ingestion**, and serve low-latency clinical and financial analytics to executive leadership via **Azure Synapse Serverless SQL** and **Power BI**.

---

## End-to-End Architecture

```mermaid
graph TD
    subgraph OnPremises["ON-PREMISES / SOURCE ENVIRONMENT"]
        DB[("Legacy Healthcare EMR<br>(PostgreSQL / SQL Server)")]
        SHIR["Self-Hosted Integration Runtime<br>(Windows Gateway)"]
        DB -->|"Local JDBC/ODBC"| SHIR
    end

    subgraph AzureSecurity["SECURITY & SECRETS LAYER"]
        AKV["Azure Key Vault (AKV)<br>(Zero-Secret Credential Store)"]
        SMI["ADF System Managed Identity<br>(RBAC: Key Vault Secrets User)"]
        SMI -->|"Retrieve DB Passwords"| AKV
    end

    subgraph AzureADF["AZURE DATA FACTORY ORCHESTRATION"]
        SHIR -->|"Outbound Port 443 HTTPS"| ADF_Pipe["ADF Ingestion Pipeline<br>(Metadata Watermark Engine)"]
        W_Table[("Watermark Control Table<br>etl_watermark_control")]
        ADF_Pipe <-->|"Lookup & Update"| W_Table
    end

    subgraph ADLS_Gen2["ADLS GEN2 MEDALLION STORAGE"]
        direction TB
        B_Zone["🥉 BRONZE LAYER<br>(Raw Delta / Parquet Ingestion)"]
        S_Zone["🥈 SILVER LAYER<br>(Cleaned, Deduplicated, PII Masked)"]
        G_Zone["🥇 GOLD LAYER<br>(Conformed Star Schema Marts)"]
        
        B_Zone -->|"Mapping Data Flow 1<br>(HIPAA SHA-256 Masking)"| S_Zone
        S_Zone -->|"Mapping Data Flow 2<br>(Dim / Fact Aggregations)"| G_Zone
    end

    ADF_Pipe -->|"1. Incremental Copy"| B_Zone

    subgraph ServingAnalytics["ANALYTICS & SERVING LAYER"]
        Synapse["Azure Synapse Analytics<br>(Serverless SQL Pool Views)"]
        PBI["Power BI Healthcare App<br>(Clinical & Financial Ops)"]
        
        G_Zone -->|"External Tables / Views"| Synapse
        Synapse -->|"DirectQuery / Import"| PBI
    end

    subgraph Governance["SOURCE CONTROL & CI/CD"]
        GitRepo["GitHub Repository<br>(Azure-Healthcare-Data-Migration)"]
        ADF_Pipe <-->|"Native ADF Git Integration"| GitRepo
    end
```

---

## Key Technical Highlights

1. **Hybrid Cloud Connectivity (SHIR)**:
   - Zero inbound firewall traversal. Local Windows Self-Hosted Integration Runtime (SHIR) creates secure outbound HTTPS (port 443) connections to Azure Data Factory.
2. **Zero-Secret Cloud Security**:
   - Azure Key Vault stores all database passwords and connection strings.
   - Azure Data Factory uses its System-Assigned Managed Identity (SMI) with `Storage Blob Data Contributor` on ADLS Gen2 and `Key Vault Secrets User` on Key Vault. No plaintext credentials are ever stored in pipeline JSON or Git.
3. **Metadata-Driven Watermark Incremental Loading**:
   - Reusable parameterized ADF copy pipelines dynamically evaluate high-watermark timestamps from a control table (`etl_watermark_control`), extracting only modified records without full table scans.
4. **Medallion Lakehouse Data Flows**:
   - **Bronze**: Append-only raw Parquet snapshot storage partitioned by ingestion date.
   - **Silver**: Deduplicated, cleansed Delta files with HIPAA-compliant SHA-256 PII hashing on sensitive attributes (`ssn`, `patient_name`).
   - **Gold**: Conformed dimensional Star Schema (`Dim_Patient`, `Dim_Provider`, `Dim_Diagnosis`, `Fact_Encounters`, `Fact_Claims`).
5. **Serverless SQL Serving Layer**:
   - Azure Synapse Serverless SQL views query Gold Delta tables on-demand via `OPENROWSET`, providing instant queryability with zero idle compute costs.
6. **Executive Power BI Reporting**:
   - High-impact dashboard visualizing Average Length of Stay (ALOS), 30-day hospital readmissions, claim denial rates %, and reimbursement cycles.

---

## Project Structure

```text
├── .agents/
│   └── rules/
│       └── migration-coaching-rule.md   # Architectural coaching & progress guidelines
├── adf/                                 # Azure Data Factory pipeline & data flow JSON definitions
│   ├── pipeline/
│   ├── dataflow/
│   ├── dataset/
│   └── linkedService/
├── docs/
│   ├── architecture_spec.md             # Detailed technical architecture specification
│   └── project_roadmap.md               # 6-Phase milestone implementation guide
├── scripts/                             # Utility PowerShell & Python automation scripts
├── sql/                                 # On-prem DDL, seed data, and Synapse Serverless SQL views
│   ├── 01_emr_schema_ddl.sql
│   ├── 02_emr_seed_data.sql
│   └── 03_synapse_views.sql
├── migration_learning_state.json        # Authoritative project progress tracker state
└── README.md                            # Executive project documentation
```
