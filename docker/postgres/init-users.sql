-- Bootstrap database users for Flyway and application access
-- This script runs on PostgreSQL container initialization before Flyway migrations

-- OWNER USER (for Flyway migrations - DDL + CRUD access)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'portfolio_owner') THEN
        CREATE ROLE portfolio_owner WITH LOGIN PASSWORD 'portfolio_owner_dev_pass';
        RAISE NOTICE 'Created role portfolio_owner';
    ELSE
        RAISE NOTICE 'Role portfolio_owner already exists';
    END IF;
END
$$;

-- Transfer database ownership to portfolio_owner (must be done as superuser)
ALTER DATABASE portfolio OWNER TO portfolio_owner;

-- Grant database connection and creation rights
GRANT CONNECT ON DATABASE portfolio TO portfolio_owner;
GRANT CREATE ON DATABASE portfolio TO portfolio_owner;

-- Grant all privileges on database
GRANT ALL PRIVILEGES ON DATABASE portfolio TO portfolio_owner;

-- Grant permissions on public schema (PostgreSQL 15+ requires explicit grants)
GRANT ALL PRIVILEGES ON SCHEMA public TO portfolio_owner;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO portfolio_owner;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO portfolio_owner;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO portfolio_owner;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO portfolio_owner;

COMMENT ON ROLE portfolio_owner IS 'Flyway migrations user - DDL and CRUD access';

-- ADMIN USER (for admin services - CRUD access)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'portfolio_admin') THEN
        CREATE ROLE portfolio_admin WITH LOGIN PASSWORD 'portfolio_admin_dev_pass';
        RAISE NOTICE 'Created role portfolio_admin';
    ELSE
        RAISE NOTICE 'Role portfolio_admin already exists';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE portfolio TO portfolio_admin;
COMMENT ON ROLE portfolio_admin IS 'Admin services user - CRUD only, no DDL';

-- PUBLIC USER (for public API - read-only access)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'portfolio_public') THEN
        CREATE ROLE portfolio_public WITH LOGIN PASSWORD 'portfolio_public_dev_pass';
        RAISE NOTICE 'Created role portfolio_public';
    ELSE
        RAISE NOTICE 'Role portfolio_public already exists';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE portfolio TO portfolio_public;
COMMENT ON ROLE portfolio_public IS 'Public API user - SELECT only';
