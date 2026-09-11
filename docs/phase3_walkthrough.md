# Phase 3 Architectural Walkthrough: Metadata-Driven Watermark Ingestion (Bronze)

## 1. Executive Summary
In **Phase 3**, we designed, deployed, and verified a production-grade **Incremental Delta Ingestion Pipeline** (`pl_ingest_incremental_bronze`) connecting our private on-premises electronic medical records (EMR) database to the raw **Bronze layer** of our Azure Medallion Lakehouse.

Rather than running expensive and disruptive full-table dumps, the pipeline employs a **High-Watermark Control Pattern** governed by an atomic SQL Server state table (`dbo.etl_watermark_control`) and a stored procedure (`dbo.usp_update_watermark`).

---

## 2. Visual Architecture Diagram (Mermaid)

```mermaid
flowchart TD
    subgraph OnPremises["🏢 On-Premises Hospital Network (DESKTOP-H5RKB3H)"]
        SQL_Source[("🗄️ SQL Server 2022 Express\nhealthcare_emr_source\ndbo.encounters (15 rows)")]
        SQL_Control[("⏱️ State Control Engine\ndbo.etl_watermark_control\nLast Watermark: 2024-02-23 15:30:00")]
        SQL_SP["⚙️ Stored Procedure\ndbo.usp_update_watermark\n(EXECUTE granted to adf_svc_user)"]
        
        SHIR["🌉 Self-Hosted Integration Runtime\nshir-onprem-gateway-01\n(DIAHostService)"]
    end

    subgraph AzureCloud["☁️ Microsoft Azure Cloud (Central India)"]
        subgraph KeyVault["🔐 Azure Key Vault (kv-healthcare-sec01)"]
            KV_Secret["Secret: sql-onprem-password\nRBAC: Key Vault Secrets User"]
        end

        subgraph ADF["🚀 Azure Data Factory (adf-healthcare-punit01)"]
            subgraph Pipeline["🔄 Pipeline: pl_ingest_incremental_bronze"]
                Act_Old["🔍 Lookup: LookupOldWatermark\nSELECT last_watermark_value\nFROM dbo.etl_watermark_control\n(Result: 1970-01-01 00:00:00)"]
                Act_New["🔍 Lookup: LookupNewWatermark\nSELECT MAX(updated_at)\nFROM dbo.encounters\n(Result: 2024-02-23 15:30:00)"]
                Act_Copy["📦 Copy Activity: CopyIncrementalEncounters\nWHERE updated_at > OldWatermark\n  AND updated_at <= NewWatermark\n(15 Rows Read ➔ 15 Rows Written)"]
                Act_SP["⚡ Stored Procedure: UpdateWatermark\nEXEC dbo.usp_update_watermark\n@TableName='encounters',\n@NewWatermarkValue=NewWatermark"]
            end
        end

        subgraph ADLS["🛢️ Azure Data Lake Storage Gen2 (sthealthcarelake01)"]
            Bronze["🥉 bronze / encounters /\nEncounters_Debug.snappy.parquet\n(Snappy-compressed columnar Parquet)"]
            Silver["🥈 silver / (Phase 4 Target: HIPAA Masking)"]
            Gold["🥇 gold / (Phase 4 Target: Star Schema Marts)"]
        end
    end

    %% Network & Flow Connections
    SHIR -- "1. Outbound HTTPS 443 Polling" --> ADF
    ADF -- "Reads DB Password via SMI" --> KV_Secret
    SHIR -- "Local Query (localhost:1433)" --> SQL_Source
    SHIR -- "Reads Watermark State" --> SQL_Control
    
    Act_Old -->|"Success"| Act_Copy
    Act_New -->|"Success"| Act_Copy
    Act_Copy -->|"Success (Terminal Commit)"| Act_SP
    
    Act_SP -- "Calls Stored Procedure via SHIR" --> SQL_SP
    SQL_SP -- "Atomically Advances Watermark" --> SQL_Control
    
    SHIR -- "2. Direct TLS 1.3 Parquet Stream" --> Bronze
    Bronze -.->|"Phase 4 Data Flow"| Silver
    Silver -.->|"Phase 4 Dimensional Modeling"| Gold

    classDef success fill:#d1fae5,stroke:#059669,stroke-width:2px,color:#065f46;
    classDef cloud fill:#eff6ff,stroke:#2563eb,stroke-width:2px,color:#1e3a8a;
    classDef onprem fill:#fffbeb,stroke:#d97706,stroke-width:2px,color:#78350f;
    classDef store fill:#ecfeff,stroke:#0891b2,stroke-width:2px,color:#0e7490;

    class Act_Old,Act_New,Act_Copy,Act_SP success;
    class ADF,KeyVault cloud;
    class OnPremises,SQL_Source,SQL_Control,SQL_SP,SHIR onprem;
    class ADLS,Bronze,Silver,Gold store;
```

---

## 3. Detailed Step-by-Step Activity Breakdown

| Activity | Name | Purpose | Underlying Query / Command | Execution Runtime | Evidence Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Activity 1** | `LookupOldWatermark` | Reads lower boundary timestamp from control table. | `SELECT last_watermark_value FROM dbo.etl_watermark_control WHERE table_name = 'encounters'` | `shir-onprem-gateway-01` (17s) | 🟢 Succeeded (`1970-01-01`) |
| **Activity 2** | `LookupNewWatermark` | Captures snapshot max timestamp from source table. | `SELECT ISNULL(MAX(updated_at), '1970-01-01') AS new_watermark FROM dbo.encounters` | `shir-onprem-gateway-01` (19s) | 🟢 Succeeded (`2024-02-23 15:30:00`) |
| **Activity 3** | `CopyIncrementalEncounters` | Streams delta records directly to ADLS Gen2 as Snappy Parquet. | Dynamic SQL query with parameterized upper & lower timestamps. | `shir-onprem-gateway-01` (18s) | 🟢 Succeeded (15 rows copied) |
| **Activity 4** | `UpdateWatermark` | Atomically commits new watermark after successful copy. | `EXEC dbo.usp_update_watermark @TableName='encounters', @NewWatermarkValue='...'` | `shir-onprem-gateway-01` (10s) | 🟢 Succeeded (State saved) |

---

## 4. Key Architectural Guarantees Established

### 1. Zero Data Loss / At-Least-Once Delivery
The stored procedure activity has an **unconditional dependency on the success of the Copy Activity**. If a network outage occurs midway through file generation, the watermark control table remains untouched. The subsequent pipeline retry extracts the exact same slice.

### 2. Snapshot Isolation Against Active Writes
Because the pipeline explicitly enforces `updated_at <= NewWatermark`, any emergency room admission or doctor note inserted into SQL Server *while* the Copy Activity is reading will be cleanly deferred to the subsequent scheduled run.

### 3. Perimeter Security (HIPAA § 164.312)
No inbound firewall rules exist on the hospital LAN router. All communication is driven outbound over **HTTPS 443 with TLS 1.3** by the Windows service daemon `DIAHostService`. Data serialization to Parquet occurs in-memory on the on-premises host before being streamed out.

---

## 5. Artifacts Generated & Committed
* **ADF Pipeline:** [adf/pipeline/pl_ingest_incremental_bronze.json](file:///d:/01_Ex_Files_Intermediate_SQL_for_Data_Scientists/Goodly%20PowerBi/Azure-Healthcare-Data-Migration/adf/pipeline/pl_ingest_incremental_bronze.json)
* **ADLS Gen2 Linked Service:** [adf/linkedService/ls_adls_healthcare.json](file:///d:/01_Ex_Files_Intermediate_SQL_for_Data_Scientists/Goodly%20PowerBi/Azure-Healthcare-Data-Migration/adf/linkedService/ls_adls_healthcare.json)
* **Bronze Dataset:** [adf/dataset/ds_adls_bronze_parquet.json](file:///d:/01_Ex_Files_Intermediate_SQL_for_Data_Scientists/Goodly%20PowerBi/Azure-Healthcare-Data-Migration/adf/dataset/ds_adls_bronze_parquet.json)
* **Source Datasets:** [adf/dataset/ds_sql_encounters.json](file:///d:/01_Ex_Files_Intermediate_SQL_for_Data_Scientists/Goodly%20PowerBi/Azure-Healthcare-Data-Migration/adf/dataset/ds_sql_encounters.json), [adf/dataset/ds_sql_watermark_control.json](file:///d:/01_Ex_Files_Intermediate_SQL_for_Data_Scientists/Goodly%20PowerBi/Azure-Healthcare-Data-Migration/adf/dataset/ds_sql_watermark_control.json)
* **SQL Stored Procedure:** [sql/04_create_watermark_stored_procedure.sql](file:///d:/01_Ex_Files_Intermediate_SQL_for_Data_Scientists/Goodly%20PowerBi/Azure-Healthcare-Data-Migration/sql/04_create_watermark_stored_procedure.sql)
* **Draw.io Architectural Blueprint:** [docs/phase3_watermark_architecture.drawio](file:///d:/01_Ex_Files_Intermediate_SQL_for_Data_Scientists/Goodly%20PowerBi/Azure-Healthcare-Data-Migration/docs/phase3_watermark_architecture.drawio)
