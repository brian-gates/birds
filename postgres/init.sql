-- Already connected to birds database created by POSTGRES_DB env var

-- Create extensions 
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Set some database-specific configuration 
ALTER DATABASE birds SET work_mem = '64MB';
ALTER DATABASE birds SET maintenance_work_mem = '256MB';
ALTER DATABASE birds SET random_page_cost = 1.1;
ALTER DATABASE birds SET effective_io_concurrency = 200;
ALTER DATABASE birds SET default_statistics_target = 500;

-- Update PostgreSQL configuration to allow all connections
-- For safety in Docker environment
ALTER SYSTEM SET listen_addresses = '*';

-- Creating a test database
CREATE DATABASE birds_test;

\c birds_test;

-- Set similar settings for the test database
ALTER DATABASE birds_test SET work_mem = '64MB';
ALTER DATABASE birds_test SET maintenance_work_mem = '256MB';
ALTER DATABASE birds_test SET random_page_cost = 1.1;
ALTER DATABASE birds_test SET effective_io_concurrency = 200;
ALTER DATABASE birds_test SET default_statistics_target = 500; 