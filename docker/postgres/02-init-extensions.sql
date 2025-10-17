-- Initialize extensions that require superuser privileges
-- This script runs before Flyway migrations as postgres superuser

\c portfolio

-- Enable pg_cron extension (requires superuser)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant cron schema usage to portfolio_owner so they can schedule jobs
GRANT USAGE ON SCHEMA cron TO portfolio_owner;
GRANT ALL ON ALL TABLES IN SCHEMA cron TO portfolio_owner;
