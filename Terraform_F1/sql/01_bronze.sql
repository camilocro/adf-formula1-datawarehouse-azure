-- ============================================================================
-- 01_bronze.sql  |  CAPA BRONZE: una tabla por archivo CSV, todo como texto
-- Proyecto Final - Campeonato del Mundo de Formula 1 (1950-2024)
-- Los datos llegan sin transformar: cualquier valor sucio queda tal cual.
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'bronze')
    EXEC(N'CREATE SCHEMA bronze');
GO

DROP TABLE IF EXISTS bronze.lap_times;
DROP TABLE IF EXISTS bronze.pit_stops;
DROP TABLE IF EXISTS bronze.qualifying;
DROP TABLE IF EXISTS bronze.sprint_results;
DROP TABLE IF EXISTS bronze.results;
DROP TABLE IF EXISTS bronze.races;
DROP TABLE IF EXISTS bronze.drivers;
DROP TABLE IF EXISTS bronze.constructors;
DROP TABLE IF EXISTS bronze.circuits;
DROP TABLE IF EXISTS bronze.status;
GO

CREATE TABLE bronze.circuits (
    [circuitId]  NVARCHAR(50)  NULL,
    [circuitRef] NVARCHAR(100) NULL,
    [name]       NVARCHAR(200) NULL,
    [location]   NVARCHAR(100) NULL,
    [country]    NVARCHAR(100) NULL,
    [lat]        NVARCHAR(50)  NULL,
    [lng]        NVARCHAR(50)  NULL,
    [alt]        NVARCHAR(50)  NULL,
    [url]        NVARCHAR(400) NULL
);

CREATE TABLE bronze.constructors (
    [constructorId]  NVARCHAR(50)  NULL,
    [constructorRef] NVARCHAR(100) NULL,
    [name]           NVARCHAR(200) NULL,
    [nationality]    NVARCHAR(100) NULL,
    [url]            NVARCHAR(400) NULL
);

CREATE TABLE bronze.drivers (
    [driverId]    NVARCHAR(50)  NULL,
    [driverRef]   NVARCHAR(100) NULL,
    [number]      NVARCHAR(50)  NULL,
    [code]        NVARCHAR(50)  NULL,
    [forename]    NVARCHAR(100) NULL,
    [surname]     NVARCHAR(100) NULL,
    [dob]         NVARCHAR(50)  NULL,
    [nationality] NVARCHAR(100) NULL,
    [url]         NVARCHAR(400) NULL
);

CREATE TABLE bronze.status (
    [statusId] NVARCHAR(50)  NULL,
    [status]   NVARCHAR(100) NULL
);

CREATE TABLE bronze.races (
    [raceId]      NVARCHAR(50)  NULL,
    [year]        NVARCHAR(50)  NULL,
    [round]       NVARCHAR(50)  NULL,
    [circuitId]   NVARCHAR(50)  NULL,
    [name]        NVARCHAR(200) NULL,
    [date]        NVARCHAR(50)  NULL,
    [time]        NVARCHAR(50)  NULL,
    [url]         NVARCHAR(400) NULL,
    [fp1_date]    NVARCHAR(50)  NULL,
    [fp1_time]    NVARCHAR(50)  NULL,
    [fp2_date]    NVARCHAR(50)  NULL,
    [fp2_time]    NVARCHAR(50)  NULL,
    [fp3_date]    NVARCHAR(50)  NULL,
    [fp3_time]    NVARCHAR(50)  NULL,
    [quali_date]  NVARCHAR(50)  NULL,
    [quali_time]  NVARCHAR(50)  NULL,
    [sprint_date] NVARCHAR(50)  NULL,
    [sprint_time] NVARCHAR(50)  NULL
);

CREATE TABLE bronze.results (
    [resultId]        NVARCHAR(50) NULL,
    [raceId]          NVARCHAR(50) NULL,
    [driverId]        NVARCHAR(50) NULL,
    [constructorId]   NVARCHAR(50) NULL,
    [number]          NVARCHAR(50) NULL,
    [grid]            NVARCHAR(50) NULL,
    [position]        NVARCHAR(50) NULL,
    [positionText]    NVARCHAR(50) NULL,
    [positionOrder]   NVARCHAR(50) NULL,
    [points]          NVARCHAR(50) NULL,
    [laps]            NVARCHAR(50) NULL,
    [time]            NVARCHAR(50) NULL,
    [milliseconds]    NVARCHAR(50) NULL,
    [fastestLap]      NVARCHAR(50) NULL,
    [rank]            NVARCHAR(50) NULL,
    [fastestLapTime]  NVARCHAR(50) NULL,
    [fastestLapSpeed] NVARCHAR(50) NULL,
    [statusId]        NVARCHAR(50) NULL
);

CREATE TABLE bronze.sprint_results (
    [resultId]       NVARCHAR(50) NULL,
    [raceId]         NVARCHAR(50) NULL,
    [driverId]       NVARCHAR(50) NULL,
    [constructorId]  NVARCHAR(50) NULL,
    [number]         NVARCHAR(50) NULL,
    [grid]           NVARCHAR(50) NULL,
    [position]       NVARCHAR(50) NULL,
    [positionText]   NVARCHAR(50) NULL,
    [positionOrder]  NVARCHAR(50) NULL,
    [points]         NVARCHAR(50) NULL,
    [laps]           NVARCHAR(50) NULL,
    [time]           NVARCHAR(50) NULL,
    [milliseconds]   NVARCHAR(50) NULL,
    [fastestLap]     NVARCHAR(50) NULL,
    [fastestLapTime] NVARCHAR(50) NULL,
    [statusId]       NVARCHAR(50) NULL
);

CREATE TABLE bronze.qualifying (
    [qualifyId]     NVARCHAR(50) NULL,
    [raceId]        NVARCHAR(50) NULL,
    [driverId]      NVARCHAR(50) NULL,
    [constructorId] NVARCHAR(50) NULL,
    [number]        NVARCHAR(50) NULL,
    [position]      NVARCHAR(50) NULL,
    [q1]            NVARCHAR(50) NULL,
    [q2]            NVARCHAR(50) NULL,
    [q3]            NVARCHAR(50) NULL
);

CREATE TABLE bronze.pit_stops (
    [raceId]       NVARCHAR(50) NULL,
    [driverId]     NVARCHAR(50) NULL,
    [stop]         NVARCHAR(50) NULL,
    [lap]          NVARCHAR(50) NULL,
    [time]         NVARCHAR(50) NULL,
    [duration]     NVARCHAR(50) NULL,
    [milliseconds] NVARCHAR(50) NULL
);

CREATE TABLE bronze.lap_times (
    [raceId]       NVARCHAR(50) NULL,
    [driverId]     NVARCHAR(50) NULL,
    [lap]          NVARCHAR(50) NULL,
    [position]     NVARCHAR(50) NULL,
    [time]         NVARCHAR(50) NULL,
    [milliseconds] NVARCHAR(50) NULL
);
GO
