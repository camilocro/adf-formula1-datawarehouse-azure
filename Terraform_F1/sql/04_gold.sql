-- ============================================================================
-- 04_gold.sql  |  CAPA GOLD: modelo estrella (6 dimensiones + 5 hechos)
-- Base: capa_gold_parte1.sql y capa_gold_parte2.sql del docente (nombres, tipos,
-- CHECK, DEFAULT y _loaded_at sin cambios). Mejoras sobre la base, marcadas
-- con la etiqueta [MEJORA]:
--   1. Miembro "Unknown" (SK = -1) en las 6 dimensiones.
--   1b. dim_date: calendario continuo 1950-2024 e is_race_day.
--   2. dim_race: circuit_id (llave de negocio del circuito) e is_sprint_weekend.
--   3. fact_race_results.is_fastest_lap.
--   4. fact_pit_stops.is_outlier_flag y fact_lap_times.is_outlier_flag.
-- Idempotente: seguro para re-ejecutar sin errores.
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'silver')
    EXEC(N'CREATE SCHEMA silver');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'gold')
    EXEC(N'CREATE SCHEMA gold');
GO

-- ----------------------------------------------------------------------------
-- 1. DIMENSIONES CONFORMADAS (compartidas por los 5 hechos)
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'gold.dim_date', N'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_date (
        date_sk           INT           NOT NULL PRIMARY KEY, -- Formato YYYYMMDD
        full_date         DATE          NOT NULL UNIQUE,
        [year]            SMALLINT      NOT NULL,
        decade            VARCHAR(10)   NOT NULL,             -- Ej: '2020s'
        [quarter]         TINYINT       NOT NULL CHECK ([quarter] BETWEEN 1 AND 4),
        [month]           TINYINT       NOT NULL CHECK ([month] BETWEEN 1 AND 12),
        month_name        VARCHAR(15)   NOT NULL,
        day_of_week       VARCHAR(15)   NOT NULL,
        is_race_day       TINYINT       NOT NULL DEFAULT 0 CHECK (is_race_day IN (0, 1))  -- [MEJORA] 1 = hubo Gran Premio ese día
    );
END;
GO

IF OBJECT_ID(N'gold.dim_race', N'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_race (
        race_sk           INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        race_id           INT               NOT NULL UNIQUE,  -- Business Key (BK)
        season_year       SMALLINT          NOT NULL,
        round_number      TINYINT           NOT NULL,
        race_name         VARCHAR(120)      NOT NULL,
        race_date         DATE              NOT NULL,
        race_time_utc     TIME(0)           NULL,
        circuit_id        INT               NOT NULL DEFAULT -1,  -- [MEJORA] BK del circuito
        is_sprint_weekend TINYINT           NOT NULL DEFAULT 0 CHECK (is_sprint_weekend IN (0, 1))  -- [MEJORA]
    );
END;
GO

IF OBJECT_ID(N'gold.dim_driver', N'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_driver (
        driver_sk         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        driver_id         INT               NOT NULL UNIQUE,  -- Business Key (BK)
        driver_ref        VARCHAR(60)       NOT NULL,
        permanent_number  SMALLINT          NULL,
        driver_code       CHAR(3)           NULL,
        forename          VARCHAR(60)       NOT NULL,
        surname           VARCHAR(60)       NOT NULL,
        full_name         VARCHAR(125)      NOT NULL,
        dob               DATE              NULL,
        nationality       VARCHAR(60)       NOT NULL DEFAULT 'Unknown'
    );
END;
GO

IF OBJECT_ID(N'gold.dim_constructor', N'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_constructor (
        constructor_sk    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        constructor_id    INT               NOT NULL UNIQUE,  -- Business Key (BK)
        constructor_ref   VARCHAR(60)       NOT NULL,
        constructor_name  VARCHAR(100)      NOT NULL,
        nationality       VARCHAR(60)       NOT NULL DEFAULT 'Unknown'
    );
END;
GO

IF OBJECT_ID(N'gold.dim_circuit', N'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_circuit (
        circuit_sk        INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        circuit_id        INT               NOT NULL UNIQUE,  -- Business Key (BK)
        circuit_ref       VARCHAR(60)       NOT NULL,
        circuit_name      VARCHAR(120)      NOT NULL,
        [location]        VARCHAR(80)       NOT NULL,
        country           VARCHAR(60)       NOT NULL,
        latitude          DECIMAL(9,6)      NULL,
        longitude         DECIMAL(9,6)      NULL,
        altitude_m        INT               NULL
    );
END;
GO

IF OBJECT_ID(N'gold.dim_status', N'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_status (
        status_sk          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        status_id          INT               NOT NULL UNIQUE, -- Business Key (BK)
        status_description VARCHAR(80)       NOT NULL,
        status_category    VARCHAR(30)       NOT NULL,        -- Finished / Mechanical / Accident / Other
        is_finished_flag   BIT               NOT NULL
    );
END;
GO

-- ----------------------------------------------------------------------------
-- 2. TABLAS DE HECHOS - PARTE 1
-- ----------------------------------------------------------------------------
-- Dependencias de fact_race_results:
--   dim_race, dim_date, dim_driver, dim_constructor, dim_circuit, dim_status
IF OBJECT_ID(N'gold.fact_race_results', N'U') IS NULL
BEGIN
    CREATE TABLE gold.fact_race_results (
        result_sk              BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        result_id              INT                  NOT NULL UNIQUE, -- Dimensión degenerada (BK)
        race_sk                INT                  NOT NULL,
        date_sk                INT                  NOT NULL,
        driver_sk              INT                  NOT NULL,
        constructor_sk         INT                  NOT NULL,
        circuit_sk             INT                  NOT NULL,
        status_sk              INT                  NOT NULL,
        grid_position          SMALLINT             NOT NULL,
        final_position         SMALLINT             NULL,
        position_order         SMALLINT             NOT NULL,
        points                 DECIMAL(6,2)         NOT NULL CHECK (points >= 0),
        laps_completed         SMALLINT             NOT NULL DEFAULT 0,
        race_time_ms           BIGINT               NULL,
        fastest_lap_ms         INT                  NULL,
        fastest_lap_speed_kph  DECIMAL(6,3)         NULL,
        is_win                 TINYINT              NOT NULL CHECK (is_win IN (0, 1)),
        is_podium              TINYINT              NOT NULL CHECK (is_podium IN (0, 1)),
        is_dnf                 TINYINT              NOT NULL CHECK (is_dnf IN (0, 1)),
        positions_gained       SMALLINT             NULL,
        driver_age_at_race     DECIMAL(4,1)         NULL,
        is_fastest_lap         TINYINT              NOT NULL DEFAULT 0 CHECK (is_fastest_lap IN (0, 1)), -- [MEJORA]
        _loaded_at             DATETIME2(0)         NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT fk_fact_results_race        FOREIGN KEY (race_sk)        REFERENCES gold.dim_race(race_sk),
        CONSTRAINT fk_fact_results_date        FOREIGN KEY (date_sk)        REFERENCES gold.dim_date(date_sk),
        CONSTRAINT fk_fact_results_driver      FOREIGN KEY (driver_sk)      REFERENCES gold.dim_driver(driver_sk),
        CONSTRAINT fk_fact_results_constructor FOREIGN KEY (constructor_sk) REFERENCES gold.dim_constructor(constructor_sk),
        CONSTRAINT fk_fact_results_circuit     FOREIGN KEY (circuit_sk)     REFERENCES gold.dim_circuit(circuit_sk),
        CONSTRAINT fk_fact_results_status      FOREIGN KEY (status_sk)      REFERENCES gold.dim_status(status_sk)
    );
END;
GO

-- Dependencias de fact_pit_stops:
--   dim_race, dim_date, dim_driver, dim_constructor, dim_circuit
IF OBJECT_ID(N'gold.fact_pit_stops', N'U') IS NULL
BEGIN
    CREATE TABLE gold.fact_pit_stops (
        pit_stop_sk       BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        race_sk           INT                  NOT NULL,
        date_sk           INT                  NOT NULL,
        driver_sk         INT                  NOT NULL,
        constructor_sk    INT                  NOT NULL,
        circuit_sk        INT                  NOT NULL,
        stop_number       TINYINT              NOT NULL CHECK (stop_number >= 1),
        lap_number        SMALLINT             NOT NULL CHECK (lap_number >= 1),
        duration_ms       INT                  NOT NULL CHECK (duration_ms > 0),
        duration_sec      DECIMAL(8,3)         NOT NULL,
        is_outlier_flag   TINYINT              NOT NULL DEFAULT 0 CHECK (is_outlier_flag IN (0, 1)), -- [MEJORA] > 120 s
        _loaded_at        DATETIME2(0)         NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT uq_fact_pit_stops_grain UNIQUE (race_sk, driver_sk, stop_number),
        CONSTRAINT fk_fact_pits_race        FOREIGN KEY (race_sk)        REFERENCES gold.dim_race(race_sk),
        CONSTRAINT fk_fact_pits_date        FOREIGN KEY (date_sk)        REFERENCES gold.dim_date(date_sk),
        CONSTRAINT fk_fact_pits_driver      FOREIGN KEY (driver_sk)      REFERENCES gold.dim_driver(driver_sk),
        CONSTRAINT fk_fact_pits_constructor FOREIGN KEY (constructor_sk) REFERENCES gold.dim_constructor(constructor_sk),
        CONSTRAINT fk_fact_pits_circuit     FOREIGN KEY (circuit_sk)     REFERENCES gold.dim_circuit(circuit_sk)
    );
END;
GO

-- ----------------------------------------------------------------------------
-- 3. TABLAS DE HECHOS - PARTE 2 (EXTENSION PARA PAREJAS)
-- ----------------------------------------------------------------------------
-- Dependencias de fact_qualifying:
--   dim_race, dim_date, dim_driver, dim_constructor, dim_circuit
IF OBJECT_ID(N'gold.fact_qualifying', N'U') IS NULL
BEGIN
    CREATE TABLE gold.fact_qualifying (
        qualifying_sk        BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        qualify_id           INT                  NOT NULL UNIQUE, -- Dimensión degenerada (BK)
        race_sk              INT                  NOT NULL,
        date_sk              INT                  NOT NULL,
        driver_sk            INT                  NOT NULL,
        constructor_sk       INT                  NOT NULL,
        circuit_sk           INT                  NOT NULL,
        car_number           SMALLINT             NULL,
        qualifying_position  SMALLINT             NOT NULL CHECK (qualifying_position >= 1),
        q1_ms                INT                  NULL CHECK (q1_ms > 0),
        q2_ms                INT                  NULL CHECK (q2_ms > 0),
        q3_ms                INT                  NULL CHECK (q3_ms > 0),
        best_qualifying_ms   INT                  NULL CHECK (best_qualifying_ms > 0),
        reached_q2           TINYINT              NOT NULL CHECK (reached_q2 IN (0, 1)),
        reached_q3           TINYINT              NOT NULL CHECK (reached_q3 IN (0, 1)),
        is_pole_position     TINYINT              NOT NULL CHECK (is_pole_position IN (0, 1)),
        _loaded_at           DATETIME2(0)         NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT fk_fact_quali_race        FOREIGN KEY (race_sk)        REFERENCES gold.dim_race(race_sk),
        CONSTRAINT fk_fact_quali_date        FOREIGN KEY (date_sk)        REFERENCES gold.dim_date(date_sk),
        CONSTRAINT fk_fact_quali_driver      FOREIGN KEY (driver_sk)      REFERENCES gold.dim_driver(driver_sk),
        CONSTRAINT fk_fact_quali_constructor FOREIGN KEY (constructor_sk) REFERENCES gold.dim_constructor(constructor_sk),
        CONSTRAINT fk_fact_quali_circuit     FOREIGN KEY (circuit_sk)     REFERENCES gold.dim_circuit(circuit_sk)
    );
END;
GO

-- Dependencias de fact_sprint_results:
--   dim_race, dim_date, dim_driver, dim_constructor, dim_circuit, dim_status
IF OBJECT_ID(N'gold.fact_sprint_results', N'U') IS NULL
BEGIN
    CREATE TABLE gold.fact_sprint_results (
        sprint_result_sk     BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        sprint_result_id     INT                  NOT NULL UNIQUE, -- Dimensión degenerada (BK)
        race_sk              INT                  NOT NULL,
        date_sk              INT                  NOT NULL,
        driver_sk            INT                  NOT NULL,
        constructor_sk       INT                  NOT NULL,
        circuit_sk           INT                  NOT NULL,
        status_sk            INT                  NOT NULL,
        grid_position        SMALLINT             NOT NULL,
        final_position       SMALLINT             NULL,
        position_order       SMALLINT             NOT NULL,
        points               DECIMAL(6,2)         NOT NULL CHECK (points >= 0),
        laps_completed       SMALLINT             NOT NULL DEFAULT 0,
        sprint_time_ms       BIGINT               NULL,
        fastest_lap_ms       INT                  NULL,
        is_sprint_win        TINYINT              NOT NULL CHECK (is_sprint_win IN (0, 1)),
        is_dnf               TINYINT              NOT NULL CHECK (is_dnf IN (0, 1)),
        positions_gained     SMALLINT             NULL,
        _loaded_at           DATETIME2(0)         NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT fk_fact_sprint_race        FOREIGN KEY (race_sk)        REFERENCES gold.dim_race(race_sk),
        CONSTRAINT fk_fact_sprint_date        FOREIGN KEY (date_sk)        REFERENCES gold.dim_date(date_sk),
        CONSTRAINT fk_fact_sprint_driver      FOREIGN KEY (driver_sk)      REFERENCES gold.dim_driver(driver_sk),
        CONSTRAINT fk_fact_sprint_constructor FOREIGN KEY (constructor_sk) REFERENCES gold.dim_constructor(constructor_sk),
        CONSTRAINT fk_fact_sprint_circuit     FOREIGN KEY (circuit_sk)     REFERENCES gold.dim_circuit(circuit_sk),
        CONSTRAINT fk_fact_sprint_status      FOREIGN KEY (status_sk)      REFERENCES gold.dim_status(status_sk)
    );
END;
GO

-- Dependencias de fact_lap_times:
--   dim_race, dim_date, dim_driver, dim_constructor, dim_circuit
IF OBJECT_ID(N'gold.fact_lap_times', N'U') IS NULL
BEGIN
    CREATE TABLE gold.fact_lap_times (
        lap_time_sk          BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        race_sk              INT                  NOT NULL,
        date_sk              INT                  NOT NULL,
        driver_sk            INT                  NOT NULL,
        constructor_sk       INT                  NOT NULL,
        circuit_sk           INT                  NOT NULL,
        lap_number           SMALLINT             NOT NULL CHECK (lap_number >= 1),
        lap_position         SMALLINT             NOT NULL CHECK (lap_position >= 1),
        lap_time_ms          INT                  NOT NULL CHECK (lap_time_ms > 0),
        lap_time_sec         DECIMAL(8,3)         NOT NULL,
        is_outlier_flag      TINYINT              NOT NULL DEFAULT 0 CHECK (is_outlier_flag IN (0, 1)), -- [MEJORA] > 300 s
        _loaded_at           DATETIME2(0)         NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT uq_fact_lap_times_grain  UNIQUE (race_sk, driver_sk, lap_number),
        CONSTRAINT fk_fact_laps_race        FOREIGN KEY (race_sk)        REFERENCES gold.dim_race(race_sk),
        CONSTRAINT fk_fact_laps_date        FOREIGN KEY (date_sk)        REFERENCES gold.dim_date(date_sk),
        CONSTRAINT fk_fact_laps_driver      FOREIGN KEY (driver_sk)      REFERENCES gold.dim_driver(driver_sk),
        CONSTRAINT fk_fact_laps_constructor FOREIGN KEY (constructor_sk) REFERENCES gold.dim_constructor(constructor_sk),
        CONSTRAINT fk_fact_laps_circuit     FOREIGN KEY (circuit_sk)     REFERENCES gold.dim_circuit(circuit_sk)
    );
END;
GO

-- ----------------------------------------------------------------------------
-- 4. INDICES ANALITICOS - PARTE 1 (CONSUMO DESDE TABLEAU)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_fact_results_date' AND object_id = OBJECT_ID(N'gold.fact_race_results'))
    CREATE NONCLUSTERED INDEX ix_fact_results_date        ON gold.fact_race_results (date_sk) INCLUDE (points, is_win, is_podium, is_dnf);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_fact_results_constructor' AND object_id = OBJECT_ID(N'gold.fact_race_results'))
    CREATE NONCLUSTERED INDEX ix_fact_results_constructor ON gold.fact_race_results (constructor_sk, date_sk) INCLUDE (points, is_win);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_fact_results_driver' AND object_id = OBJECT_ID(N'gold.fact_race_results'))
    CREATE NONCLUSTERED INDEX ix_fact_results_driver      ON gold.fact_race_results (driver_sk, date_sk) INCLUDE (points, is_win, is_podium, positions_gained);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_fact_results_circuit' AND object_id = OBJECT_ID(N'gold.fact_race_results'))
    CREATE NONCLUSTERED INDEX ix_fact_results_circuit     ON gold.fact_race_results (circuit_sk) INCLUDE (fastest_lap_speed_kph);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_fact_pits_constructor' AND object_id = OBJECT_ID(N'gold.fact_pit_stops'))
    CREATE NONCLUSTERED INDEX ix_fact_pits_constructor    ON gold.fact_pit_stops (constructor_sk, date_sk) INCLUDE (duration_ms, duration_sec);
GO
-- ----------------------------------------------------------------------------
-- 5. INDICES ANALITICOS - PARTE 2 (CONSUMO DESDE TABLEAU)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_fact_quali_driver' AND object_id = OBJECT_ID(N'gold.fact_qualifying'))
    CREATE NONCLUSTERED INDEX ix_fact_quali_driver      ON gold.fact_qualifying (driver_sk, date_sk) INCLUDE (qualifying_position, is_pole_position, best_qualifying_ms);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_fact_quali_constructor' AND object_id = OBJECT_ID(N'gold.fact_qualifying'))
    CREATE NONCLUSTERED INDEX ix_fact_quali_constructor ON gold.fact_qualifying (constructor_sk, date_sk) INCLUDE (reached_q3, is_pole_position);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_fact_sprint_driver' AND object_id = OBJECT_ID(N'gold.fact_sprint_results'))
    CREATE NONCLUSTERED INDEX ix_fact_sprint_driver     ON gold.fact_sprint_results (driver_sk, date_sk) INCLUDE (points, is_sprint_win);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_fact_laps_race_driver' AND object_id = OBJECT_ID(N'gold.fact_lap_times'))
    CREATE NONCLUSTERED INDEX ix_fact_laps_race_driver  ON gold.fact_lap_times (race_sk, driver_sk) INCLUDE (lap_number, lap_position, lap_time_sec);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_fact_laps_circuit_date' AND object_id = OBJECT_ID(N'gold.fact_lap_times'))
    CREATE NONCLUSTERED INDEX ix_fact_laps_circuit_date ON gold.fact_lap_times (circuit_sk, date_sk) INCLUDE (lap_time_sec);
GO
-- ----------------------------------------------------------------------------
-- 6. [MEJORA] MIEMBRO DESCONOCIDO (SK = -1) EN CADA DIMENSION
--    Los flujos de Gold usan coalesce(sk, -1): una fila sin dimension asociada
--    se conserva en el hecho en lugar de perderse.
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM gold.dim_date WHERE date_sk = -1)
    INSERT INTO gold.dim_date (date_sk, full_date, [year], decade, [quarter], [month], month_name, day_of_week)
    VALUES (-1, '1900-01-01', 1900, '1900s', 1, 1, 'Unknown', 'Unknown');
GO

IF NOT EXISTS (SELECT 1 FROM gold.dim_race WHERE race_sk = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_race ON;
    INSERT INTO gold.dim_race (race_sk, race_id, season_year, round_number, race_name, race_date, race_time_utc, circuit_id, is_sprint_weekend)
    VALUES (-1, -1, 1900, 0, 'Unknown', '1900-01-01', NULL, -1, 0);
    SET IDENTITY_INSERT gold.dim_race OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM gold.dim_driver WHERE driver_sk = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_driver ON;
    INSERT INTO gold.dim_driver (driver_sk, driver_id, driver_ref, permanent_number, driver_code, forename, surname, full_name, dob, nationality)
    VALUES (-1, -1, 'unknown', NULL, NULL, 'Unknown', 'Unknown', 'Unknown', NULL, 'Unknown');
    SET IDENTITY_INSERT gold.dim_driver OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM gold.dim_constructor WHERE constructor_sk = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_constructor ON;
    INSERT INTO gold.dim_constructor (constructor_sk, constructor_id, constructor_ref, constructor_name, nationality)
    VALUES (-1, -1, 'unknown', 'Unknown', 'Unknown');
    SET IDENTITY_INSERT gold.dim_constructor OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM gold.dim_circuit WHERE circuit_sk = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_circuit ON;
    INSERT INTO gold.dim_circuit (circuit_sk, circuit_id, circuit_ref, circuit_name, [location], country, latitude, longitude, altitude_m)
    VALUES (-1, -1, 'unknown', 'Unknown', 'Unknown', 'Unknown', NULL, NULL, NULL);
    SET IDENTITY_INSERT gold.dim_circuit OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM gold.dim_status WHERE status_sk = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_status ON;
    INSERT INTO gold.dim_status (status_sk, status_id, status_description, status_category, is_finished_flag)
    VALUES (-1, -1, 'Unknown', 'Other', 0);
    SET IDENTITY_INSERT gold.dim_status OFF;
END;
GO
