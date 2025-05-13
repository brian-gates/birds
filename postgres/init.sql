-- Create the database if it doesn't exist
SELECT 'CREATE DATABASE tree_node_api_development'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tree_node_api_development')\gexec

-- Connect to the database
\c tree_node_api_development;

-- Create extensions 
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Set some database-specific configuration 
ALTER DATABASE tree_node_api_development SET work_mem = '64MB';
ALTER DATABASE tree_node_api_development SET maintenance_work_mem = '256MB';
ALTER DATABASE tree_node_api_development SET random_page_cost = 1.1;
ALTER DATABASE tree_node_api_development SET effective_io_concurrency = 200;
ALTER DATABASE tree_node_api_development SET default_statistics_target = 500;

-- Update PostgreSQL configuration to allow all connections
-- For safety in Docker environment
ALTER SYSTEM SET listen_addresses = '*';

-- Creating a test database as well
SELECT 'CREATE DATABASE tree_node_api_test'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tree_node_api_test')\gexec

\c tree_node_api_test;

-- Set similar settings for the test database
ALTER DATABASE tree_node_api_test SET work_mem = '64MB';
ALTER DATABASE tree_node_api_test SET maintenance_work_mem = '256MB';
ALTER DATABASE tree_node_api_test SET random_page_cost = 1.1; 