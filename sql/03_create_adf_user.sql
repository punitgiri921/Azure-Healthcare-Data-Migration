-- ============================================================================
-- SCRIPT 03: Create Dedicated Service Account for Azure Data Factory (SHIR)
-- Project: Azure Healthcare Data Migration & Medallion Lakehouse
-- Target: Microsoft SQL Server (.\SQLEXPRESS)
-- ============================================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'adf_svc_user')
BEGIN
    CREATE LOGIN [adf_svc_user] WITH PASSWORD = N'HealthLakehouse2026!Secure', CHECK_EXPIRATION = OFF, CHECK_POLICY = OFF;
    PRINT 'Login [adf_svc_user] created successfully.';
END
ELSE
BEGIN
    ALTER LOGIN [adf_svc_user] WITH PASSWORD = N'HealthLakehouse2026!Secure';
    PRINT 'Login [adf_svc_user] password updated.';
END
GO

USE healthcare_emr_source;
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'adf_svc_user')
BEGIN
    CREATE USER [adf_svc_user] FOR LOGIN [adf_svc_user];
    PRINT 'User [adf_svc_user] mapped in [healthcare_emr_source].';
END
GO

ALTER ROLE [db_datareader] ADD MEMBER [adf_svc_user];
ALTER ROLE [db_datawriter] ADD MEMBER [adf_svc_user];
GO

PRINT 'Permissions granted to [adf_svc_user] successfully.';
GO
