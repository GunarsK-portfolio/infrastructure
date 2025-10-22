FROM postgres:18-alpine

# Update Alpine packages to fix vulnerabilities and install gettext for envsubst
RUN apk upgrade --no-cache \
    && apk add --no-cache gettext

# Install build dependencies and PostgreSQL extensions
RUN apk add --no-cache --virtual .build-deps \
        git \
        build-base \
        postgresql-dev \
        clang19 \
        llvm19 \
    && cd /tmp \
    # Install pg_partman v5.3.0
    && git clone --branch v5.3.0 --depth 1 https://github.com/pgpartman/pg_partman.git \
    && cd pg_partman \
    && make \
    && make install \
    && cd /tmp \
    # Install pg_cron v1.6.7 for scheduled jobs
    && git clone --branch v1.6.7 --depth 1 https://github.com/citusdata/pg_cron.git \
    && cd pg_cron \
    && make \
    && make install \
    && cd / \
    && rm -rf /tmp/pg_partman /tmp/pg_cron \
    && apk del .build-deps

# Extensions installed: pg_partman v5.3.0, pg_cron v1.6.7
