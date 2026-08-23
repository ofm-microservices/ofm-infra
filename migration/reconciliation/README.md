# Reconciliation

Reconciliation runs after snapshot, during shadow mode, and before ownership
cutover. It compares normalized identifiers, public fields and aggregate
versions. It reports mismatches and does not repair data automatically.

Any repair must be a new idempotent migration event and must be auditable.

For exported normalized CSVs, run:

```sh
./migration/reconciliation/reconcile_users.py monolith-users.csv service-users.csv
```

Exit status `0` means no mismatches; `1` means mismatches were reported.
The command never repairs data.
