# Auth/User initial snapshot

The snapshot is executed before enabling live routing. The source is the
monolith PostgreSQL database and the destination is the service-owned
YugabyteDB. Run the exports with a consistent source snapshot and record the
CDC position before releasing writes to the microservices.

Required checks after import:

- counts and UUID sets for users and auth credentials;
- username/email uniqueness;
- email verification and active status;
- aggregate versions and CDC slot position;
- no password hashes in migration events or logs.

For an executable import, prepare two secured CSV files with the explicit
headers consumed by `load_snapshot.sh` and run:

```sh
SNAPSHOT_DIR=/secure/ofm-snapshot \
AUTH_DATABASE_URL=postgres://... \
USER_DATABASE_URL=postgres://... \
./migration/snapshot/load_snapshot.sh
```

The auth CSV contains the credential columns, including the password hash,
only for the secured database-to-database snapshot channel. It must not be
placed in the CDC event payload or committed to the workspace.

The exact column mapping is intentionally explicit in the SQL templates below;
do not use `SELECT *` across the bounded-context boundary.
