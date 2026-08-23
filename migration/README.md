# Migration infrastructure

Debezium source profiles capture only service-owned Yugabyte tables. The
Yugabyte WAL is the CDC source, Kafka is the migration transport, and the
Migration Bridge owns canonical event mapping and Schema Registry validation.
NATS JetStream is not part of the migration runtime.

Register canonical JSON schemas after Apicurio Registry is running:

```sh
./migration/register-schemas.sh
```

Debezium profiles intentionally preserve the native change envelope.
The bridge derives the source service from explicit `source.service` metadata
when present, or from the Yugabyte database name (`auth_service` or
`user_service`). Do not enable `ExtractNewRecordState` for these profiles,
because it removes the table and operation metadata required for canonical
event mapping.

The runnable migration topology must provide one Yugabyte-compatible Debezium
connector per bounded context, Kafka source topics, Schema Registry, and one
Kafka-to-canonical-event Migration Bridge per bounded context. Start it with
the relevant service compose files using the migration profile.
