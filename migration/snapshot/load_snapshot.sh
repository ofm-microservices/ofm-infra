#!/bin/sh
set -eu

# Loads an already secured, explicitly shaped snapshot into the service-owned
# PostgreSQL databases. The CSV files are staging inputs; they are never emitted
# to logs and are removed by the caller according to its retention policy.

command -v psql >/dev/null 2>&1 || { echo "psql is required" >&2; exit 1; }

SNAPSHOT_DIR=${SNAPSHOT_DIR:?SNAPSHOT_DIR must point to the secured snapshot directory}
AUTH_DATABASE_URL=${AUTH_DATABASE_URL:?AUTH_DATABASE_URL is required}
USER_DATABASE_URL=${USER_DATABASE_URL:?USER_DATABASE_URL is required}

for file in auth_credentials.csv users.csv; do
  test -r "$SNAPSHOT_DIR/$file" || { echo "missing snapshot: $SNAPSHOT_DIR/$file" >&2; exit 1; }
done

psql "$AUTH_DATABASE_URL" -v ON_ERROR_STOP=1 \
  -c "CREATE TEMP TABLE monolith_users_snapshot (user_id UUID NOT NULL, email TEXT NOT NULL, username TEXT NOT NULL, first_name TEXT NOT NULL, surname TEXT NOT NULL, password_hash TEXT NOT NULL, email_verified BOOLEAN NOT NULL, status TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL, updated_at TIMESTAMPTZ NOT NULL)" \
  -c "\\copy monolith_users_snapshot(user_id,email,username,first_name,surname,password_hash,email_verified,status,created_at,updated_at) FROM '$SNAPSHOT_DIR/auth_credentials.csv' WITH (FORMAT csv, HEADER true)" \
  -f "$(dirname "$0")/auth.sql"

psql "$USER_DATABASE_URL" -v ON_ERROR_STOP=1 \
  -c "CREATE TEMP TABLE monolith_users_snapshot (user_id UUID NOT NULL, username TEXT NOT NULL, first_name TEXT NOT NULL, surname TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL, updated_at TIMESTAMPTZ NOT NULL)" \
  -c "\\copy monolith_users_snapshot(user_id,username,first_name,surname,created_at,updated_at) FROM '$SNAPSHOT_DIR/users.csv' WITH (FORMAT csv, HEADER true)" \
  -f "$(dirname "$0")/user.sql"
