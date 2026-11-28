-- ============================================================================
-- 03_cuarentena.sql  |  TABLA DE CUARENTENA EN SILVER (rechazos de calidad e integridad)
-- Estructura del docente (capa_gold_parte1.sql, seccion 1), sin cambios.
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'silver')
    EXEC(N'CREATE SCHEMA silver');
GO

IF OBJECT_ID(N'silver.quarantine_results', N'U') IS NULL
BEGIN
    CREATE TABLE silver.quarantine_results (
        quarantine_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
        raw_result_id      VARCHAR(50)   NULL,
        raw_race_id        VARCHAR(50)   NULL,
        raw_driver_id      VARCHAR(50)   NULL,
        raw_constructor_id VARCHAR(50)   NULL,
        raw_points         VARCHAR(50)   NULL,
        quarantine_reason  VARCHAR(120)  NOT NULL,
        _source_file       VARCHAR(255)  NOT NULL,
        _rejected_at       DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );
END;
GO
