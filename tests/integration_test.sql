-- Integration test: verify core objects exist and are queryable
-- Run against the target environment database

-- Verify RAW schema tables
SELECT 'RAW schema' AS test, COUNT(*) AS table_count
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'RAW';

-- Verify CLEAN schema tables
SELECT 'CLEAN schema' AS test, COUNT(*) AS table_count
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CLEAN';

-- Verify CONFORMED schema tables
SELECT 'CONFORMED schema' AS test, COUNT(*) AS table_count
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CONFORMED';

-- Verify GOVERNANCE schema objects
SELECT 'GOVERNANCE schema' AS test, COUNT(*) AS table_count
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'GOVERNANCE';
