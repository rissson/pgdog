#!/bin/bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
export PGPASSWORD=pgdog
export PGPORT=6432
export PGHOST=127.0.0.1

killall -TERM pgdog 2>/dev/null || true

PGDOG_BIN_PATH="${PGDOG_BIN:-${SCRIPT_DIR}/../../../target/release/pgdog}"

"${PGDOG_BIN_PATH}" \
    --config ${SCRIPT_DIR}/pgdog-enabled.toml \
    --users ${SCRIPT_DIR}/users.toml &
PGDOG_PID=$!

until pg_isready -h 127.0.0.1 -p 6432 -U pgdog -d pgdog; do
    sleep 1
done

# Establish initial connection with expected password
psql -U pgdog1 pgdog -c 'SELECT 1' >/dev/null

# Change password
psql -U pgdog pgdog -c "ALTER USER pgdog1 WITH PASSWORD 'new_password'" >/dev/null

# Check that user can still connect
PGPASSWORD=new_password psql -U pgdog1 pgdog -c 'SELECT 1' >/dev/null

# Restore password for other tests
psql -U pgdog pgdog -c "ALTER USER pgdog1 WITH PASSWORD 'pgdog'" >/dev/null

killall -TERM pgdog
wait "${PGDOG_PID}" 2>/dev/null || true
