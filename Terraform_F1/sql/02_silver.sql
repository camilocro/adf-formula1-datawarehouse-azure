-- ============================================================================
-- 02_silver.sql  |  CAPA SILVER: tablas tipadas con llaves primarias y foraneas
-- Los datos entran limpios: sin duplicados, sin llaves huerfanas, con tipos reales.
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'silver')
    EXEC(N'CREATE SCHEMA silver');
GO

-- Se eliminan primero las tablas hijas y al final las padres.
DROP TABLE IF EXISTS silver.lap_times;
DROP TABLE IF EXISTS silver.pit_stops;
DROP TABLE IF EXISTS silver.qualifying;
DROP TABLE IF EXISTS silver.sprint_results;
DROP TABLE IF EXISTS silver.results;
DROP TABLE IF EXISTS silver.races;
DROP TABLE IF EXISTS silver.drivers;
DROP TABLE IF EXISTS silver.constructors;
DROP TABLE IF EXISTS silver.circuits;
DROP TABLE IF EXISTS silver.status;
GO

CREATE TABLE silver.status (
    status_id          INT          NOT NULL PRIMARY KEY,
    status_description VARCHAR(80)  NOT NULL
);

CREATE TABLE silver.circuits (
    circuit_id    INT           NOT NULL PRIMARY KEY,
    circuit_ref   VARCHAR(60)   NOT NULL,
    circuit_name  VARCHAR(120)  NOT NULL,
    [location]    VARCHAR(80)   NOT NULL,
    country       VARCHAR(60)   NOT NULL,
    latitude      DECIMAL(9,6)  NULL,
    longitude     DECIMAL(9,6)  NULL,
    altitude_m    INT           NULL
);

CREATE TABLE silver.constructors (
    constructor_id   INT          NOT NULL PRIMARY KEY,
    constructor_ref  VARCHAR(60)  NOT NULL,
    constructor_name VARCHAR(100) NOT NULL,
    nationality      VARCHAR(60)  NOT NULL DEFAULT 'Unknown'
);

CREATE TABLE silver.drivers (
    driver_id         INT          NOT NULL PRIMARY KEY,
    driver_ref        VARCHAR(60)  NOT NULL,
    permanent_number  SMALLINT     NULL,
    driver_code       CHAR(3)      NULL,
    forename          VARCHAR(60)  NOT NULL,
    surname           VARCHAR(60)  NOT NULL,
    dob               DATE         NULL,
    nationality       VARCHAR(60)  NOT NULL DEFAULT 'Unknown'
);

CREATE TABLE silver.races (
    race_id        INT           NOT NULL PRIMARY KEY,
    season_year    SMALLINT      NOT NULL,
    round_number   SMALLINT      NOT NULL,
    circuit_id     INT           NOT NULL,
    race_name      VARCHAR(120)  NOT NULL,
    race_date      DATE          NOT NULL,
    race_time_utc  VARCHAR(8)    NULL,           -- texto HH:mm:ss; Gold lo guarda como TIME(0)
    sprint_date    DATE          NULL,
    CONSTRAINT fk_silver_races_circuit FOREIGN KEY (circuit_id) REFERENCES silver.circuits(circuit_id)
);

CREATE TABLE silver.results (
    result_id              INT           NOT NULL PRIMARY KEY,
    race_id                INT           NOT NULL,
    driver_id              INT           NOT NULL,
    constructor_id         INT           NOT NULL,
    status_id              INT           NOT NULL,
    car_number             SMALLINT      NULL,
    grid_position          SMALLINT      NOT NULL,
    final_position         SMALLINT      NULL,
    position_order         SMALLINT      NOT NULL,
    points                 DECIMAL(6,2)  NOT NULL CHECK (points >= 0),
    laps_completed         SMALLINT      NOT NULL,
    race_time_ms           BIGINT        NULL,
    fastest_lap_number     SMALLINT      NULL,
    fastest_lap_rank       SMALLINT      NULL,
    fastest_lap_ms         INT           NULL,
    fastest_lap_speed_kph  DECIMAL(6,3)  NULL,
    CONSTRAINT fk_silver_results_race        FOREIGN KEY (race_id)        REFERENCES silver.races(race_id),
    CONSTRAINT fk_silver_results_driver      FOREIGN KEY (driver_id)      REFERENCES silver.drivers(driver_id),
    CONSTRAINT fk_silver_results_constructor FOREIGN KEY (constructor_id) REFERENCES silver.constructors(constructor_id),
    CONSTRAINT fk_silver_results_status      FOREIGN KEY (status_id)      REFERENCES silver.status(status_id)
);

CREATE TABLE silver.sprint_results (
    sprint_result_id    INT           NOT NULL PRIMARY KEY,
    race_id             INT           NOT NULL,
    driver_id           INT           NOT NULL,
    constructor_id      INT           NOT NULL,
    status_id           INT           NOT NULL,
    car_number          SMALLINT      NULL,
    grid_position       SMALLINT      NOT NULL,
    final_position      SMALLINT      NULL,
    position_order      SMALLINT      NOT NULL,
    points              DECIMAL(6,2)  NOT NULL CHECK (points >= 0),
    laps_completed      SMALLINT      NOT NULL,
    sprint_time_ms      BIGINT        NULL,
    fastest_lap_number  SMALLINT      NULL,
    fastest_lap_ms      INT           NULL,
    CONSTRAINT fk_silver_sprint_race        FOREIGN KEY (race_id)        REFERENCES silver.races(race_id),
    CONSTRAINT fk_silver_sprint_driver      FOREIGN KEY (driver_id)      REFERENCES silver.drivers(driver_id),
    CONSTRAINT fk_silver_sprint_constructor FOREIGN KEY (constructor_id) REFERENCES silver.constructors(constructor_id),
    CONSTRAINT fk_silver_sprint_status      FOREIGN KEY (status_id)      REFERENCES silver.status(status_id)
);

CREATE TABLE silver.qualifying (
    qualify_id           INT       NOT NULL PRIMARY KEY,
    race_id              INT       NOT NULL,
    driver_id            INT       NOT NULL,
    constructor_id       INT       NOT NULL,
    car_number           SMALLINT  NULL,
    qualifying_position  SMALLINT  NOT NULL,
    q1_ms                INT       NULL,
    q2_ms                INT       NULL,
    q3_ms                INT       NULL,
    CONSTRAINT fk_silver_quali_race        FOREIGN KEY (race_id)        REFERENCES silver.races(race_id),
    CONSTRAINT fk_silver_quali_driver      FOREIGN KEY (driver_id)      REFERENCES silver.drivers(driver_id),
    CONSTRAINT fk_silver_quali_constructor FOREIGN KEY (constructor_id) REFERENCES silver.constructors(constructor_id)
);

CREATE TABLE silver.pit_stops (
    race_id      INT       NOT NULL,
    driver_id    INT       NOT NULL,
    stop_number  SMALLINT  NOT NULL,
    lap_number   SMALLINT  NOT NULL,
    duration_ms  INT       NOT NULL,
    CONSTRAINT pk_silver_pit_stops PRIMARY KEY (race_id, driver_id, stop_number),
    CONSTRAINT fk_silver_pits_race   FOREIGN KEY (race_id)   REFERENCES silver.races(race_id),
    CONSTRAINT fk_silver_pits_driver FOREIGN KEY (driver_id) REFERENCES silver.drivers(driver_id)
);

CREATE TABLE silver.lap_times (
    race_id       INT       NOT NULL,
    driver_id     INT       NOT NULL,
    lap_number    SMALLINT  NOT NULL,
    lap_position  SMALLINT  NOT NULL,
    lap_time_ms   INT       NOT NULL,
    CONSTRAINT pk_silver_lap_times PRIMARY KEY (race_id, driver_id, lap_number),
    CONSTRAINT fk_silver_laps_race   FOREIGN KEY (race_id)   REFERENCES silver.races(race_id),
    CONSTRAINT fk_silver_laps_driver FOREIGN KEY (driver_id) REFERENCES silver.drivers(driver_id)
);
GO
