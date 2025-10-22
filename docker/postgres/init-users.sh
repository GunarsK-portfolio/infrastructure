#!/bin/sh
# Wrapper script to substitute environment variables in init-users.sql
# This runs in the postgres docker-entrypoint-initdb.d phase

set -e

# Process the SQL template and execute it
envsubst < /docker-entrypoint-initdb.d/init-users.sql.template | psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"
