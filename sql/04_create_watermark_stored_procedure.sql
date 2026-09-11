-- ============================================================================
-- SCRIPT 04: Create Watermark Update Stored Procedure
-- Project: Azure Healthcare Data Migration & Medallion Lakehouse
-- Target: Microsoft SQL Server (.\SQLEXPRESS) / healthcare_emr_source
-- ============================================================================

USE healthcare_emr_source;
GO

IF OBJECT_ID('dbo.usp_update_watermark', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_update_watermark;
GO

CREATE PROCEDURE dbo.usp_update_watermark
    @TableName VARCHAR(100),
    @NewWatermarkValue DATETIME2(3)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate input parameters
    IF @TableName IS NULL OR @NewWatermarkValue IS NULL
    BEGIN
        RAISERROR('TableName and NewWatermarkValue cannot be NULL.', 16, 1);
        RETURN;
    END

    -- Update or insert watermark state atomically
    UPDATE dbo.etl_watermark_control
    SET 
        last_watermark_value = @NewWatermarkValue,
        status = 'SUCCESS',
        last_run_timestamp = SYSUTCDATETIME()
    WHERE table_name = @TableName;

    -- Verify that a record was updated
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('Table name [%s] was not found in dbo.etl_watermark_control.', 16, 1, @TableName);
        RETURN;
    END

    PRINT 'Watermark for table [' + @TableName + '] updated to ' + CONVERT(VARCHAR(30), @NewWatermarkValue, 121);
END;
GO

-- Grant execution permissions to ADF service account
GRANT EXECUTE ON dbo.usp_update_watermark TO [adf_svc_user];
GO

PRINT 'Stored procedure [dbo.usp_update_watermark] created and permissions granted successfully.';
GO
