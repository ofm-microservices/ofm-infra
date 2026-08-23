# Compact migration runtime

For a resource-constrained local machine, start the shared Kafka and Schema
Registry together with one Debezium worker and one canonical migration bridge:

```sh
docker compose \
  -f docker-compose.migration.yaml \
  -f docker-compose.migration-compact.yaml \
  up -d --build
```

`migration-debezium` runs the six Yugabyte CDC connector configurations in one
container and uses a separate offsets file for each connector. `migration-bridge`
reads all `cdc.*.public.outbox_events` topics and publishes the canonical
`migration.*` topics consumed by the monolith. The existing per-service
runtime file remains available for machines that need connector isolation.

The service databases must already be reachable on the shared `ofm-infra`
Docker network under their service names (`gig-service-yugabyte`,
`order-service-yugabyte`, and so on).
