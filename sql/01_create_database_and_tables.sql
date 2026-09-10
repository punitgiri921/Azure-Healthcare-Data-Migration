-- ============================================================================
-- SCRIPT 01: Create Database and On-Prem EMR Tables
-- Project: Azure Healthcare Data Migration & Medallion Lakehouse
-- Target: Microsoft SQL Server (.\SQLEXPRESS) / On-Premises Simulation
-- ============================================================================

-- 1. Create Database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'healthcare_emr_source')
BEGIN
    CREATE DATABASE healthcare_emr_source;
    PRINT 'Database [healthcare_emr_source] created successfully.';
END
ELSE
BEGIN
    PRINT 'Database [healthcare_emr_source] already exists.';
END
GO

USE healthcare_emr_source;
GO

-- 2. Clean up existing tables for idempotent execution
IF OBJECT_ID('dbo.claims', 'U') IS NOT NULL DROP TABLE dbo.claims;
IF OBJECT_ID('dbo.diagnoses', 'U') IS NOT NULL DROP TABLE dbo.diagnoses;
IF OBJECT_ID('dbo.encounters', 'U') IS NOT NULL DROP TABLE dbo.encounters;
IF OBJECT_ID('dbo.patients', 'U') IS NOT NULL DROP TABLE dbo.patients;
IF OBJECT_ID('dbo.providers', 'U') IS NOT NULL DROP TABLE dbo.providers;
IF OBJECT_ID('dbo.etl_watermark_control', 'U') IS NOT NULL DROP TABLE dbo.etl_watermark_control;
GO

-- 3. Providers Table
CREATE TABLE dbo.providers (
    provider_id INT IDENTITY(101, 1) PRIMARY KEY,
    provider_name NVARCHAR(150) NOT NULL,
    specialty NVARCHAR(100) NOT NULL,
    department NVARCHAR(100) NOT NULL,
    npi_number VARCHAR(10) NOT NULL UNIQUE,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- 4. Patients Table (Contains PII to be masked in Silver Layer)
CREATE TABLE dbo.patients (
    patient_id INT IDENTITY(1001, 1) PRIMARY KEY,
    first_name NVARCHAR(100) NOT NULL,
    last_name NVARCHAR(100) NOT NULL,
    ssn VARCHAR(11) NOT NULL,
    dob DATE NOT NULL,
    gender VARCHAR(10) NOT NULL,
    address NVARCHAR(200) NULL,
    city NVARCHAR(100) NULL,
    state VARCHAR(2) NULL,
    zip VARCHAR(10) NULL,
    insurance_id VARCHAR(50) NULL,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- 5. Encounters Table (Clinical Admissions & Visits)
CREATE TABLE dbo.encounters (
    encounter_id INT IDENTITY(5001, 1) PRIMARY KEY,
    patient_id INT NOT NULL,
    provider_id INT NOT NULL,
    admission_date DATETIME2(3) NOT NULL,
    discharge_date DATETIME2(3) NULL,
    encounter_type NVARCHAR(50) NOT NULL, -- Inpatient, Outpatient, Emergency, Telehealth
    department NVARCHAR(100) NOT NULL,
    discharge_disposition NVARCHAR(100) NULL, -- Home, Transferred, Deceased, AMA
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Encounters_Patients FOREIGN KEY (patient_id) REFERENCES dbo.patients(patient_id),
    CONSTRAINT FK_Encounters_Providers FOREIGN KEY (provider_id) REFERENCES dbo.providers(provider_id)
);
GO

-- 6. Diagnoses Table (ICD-10 Coding)
CREATE TABLE dbo.diagnoses (
    diagnosis_id INT IDENTITY(8001, 1) PRIMARY KEY,
    encounter_id INT NOT NULL,
    icd10_code VARCHAR(10) NOT NULL,
    diagnosis_description NVARCHAR(255) NOT NULL,
    is_primary BIT NOT NULL DEFAULT 1,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Diagnoses_Encounters FOREIGN KEY (encounter_id) REFERENCES dbo.encounters(encounter_id)
);
GO

-- 7. Claims Table (Financial Billing & Payor Settlement)
CREATE TABLE dbo.claims (
    claim_id INT IDENTITY(9001, 1) PRIMARY KEY,
    encounter_id INT NOT NULL,
    billed_amount DECIMAL(18, 2) NOT NULL,
    paid_amount DECIMAL(18, 2) NOT NULL,
    claim_status NVARCHAR(50) NOT NULL, -- Approved, Denied, Pending
    denial_reason NVARCHAR(255) NULL,
    submitted_date DATE NOT NULL,
    paid_date DATE NULL,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Claims_Encounters FOREIGN KEY (encounter_id) REFERENCES dbo.encounters(encounter_id)
);
GO

-- 8. Watermark Control Table (Critical for Incremental Delta Ingestion)
CREATE TABLE dbo.etl_watermark_control (
    table_name VARCHAR(100) PRIMARY KEY,
    watermark_column VARCHAR(100) NOT NULL,
    last_watermark_value DATETIME2(3) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'INIT',
    last_run_timestamp DATETIME2(3) NULL
);
GO

PRINT 'All tables and constraints created successfully.';
GO
