# OFM Infra

This repository owns the local development orchestration for the OFM microservices stack.

It does not own service business logic. It owns how the services are built, started, and observed together in local development.

## Stack

The local stack currently includes:

- `nats`
- `user-service-yugabyte`
- `user-service-redis`
- `auth-service-yugabyte`
- `registration-saga-service-scylla`

## Compose

The stack is split across dedicated Compose files:

- `docker-compose.nats.yaml`
- `docker-compose.user-service.yaml`
- `docker-compose.auth-service.yaml`
- `docker-compose.registration-saga-service.yaml`

Run the full stack with:

```bash
cd ofm-infra
just infra-all
```

Useful Compose commands:

```bash
just infra-up
just infra-all
just infra-down
just infra-logs
just infra-ps
```

## Tilt

Tilt is the preferred interactive runner for the Go applications only.

The runtime split is intentional:

- Docker Compose runs third-party infrastructure containers outside Tilt
- Tilt runs only your Go services as local processes with `go run`

That keeps application iteration fast while leaving NATS, YugabyteDB, Redis, and ScyllaDB in containers.

The Tilt entrypoint is [Tiltfile](/home/alex/projects/ofm-microservices/ofm-infra/Tiltfile).

Start Tilt with:

```bash
cd ofm-infra
just tilt-up
```

Or directly:

```bash
cd ofm-infra
tilt up
```

Stop Tilt with:

```bash
cd ofm-infra
just tilt-down
```

### Tilt resource layout

Tilt exposes only local Go application resources:

- `registration-saga-service`
- `auth-service`
- `user-service`
- `mail-service`
- `api-gateway`

Resources are labeled for filtering:

- `app`
  Long-running Go services started by Tilt
- service-specific labels such as `api-gateway`, `auth-service`, `user-service`, `registration-saga-service`

## Tooling

This repo currently uses:

- `Docker Compose`
- `Tilt`
- `Just`
- `AsyncAPI CLI`
- `pkgsite`
- `swaggerapi/swagger-ui`
- `grpc-docs`
- `SonarQube`

## Notes

- Compose remains the source of truth for third-party infra containers and must be started separately.
- Tilt owns only the Go application process lifecycle.
- Service environment variables remain in the service-local `.env` files.
- Tilt overrides Docker-network connection targets to host values such as `127.0.0.1` and published ports when running `go run` locally.

## Swagger

Swagger generation is limited to the `api-gateway` HTTP package. The source
annotations live in `ofm-api-gateway/internal/presentation/http/doc.go`, and
the generated OpenAPI files are written to `ofm-docs/swagger/api-gateway`.

Build the OpenAPI files:

```bash
cd ofm-infra
just swagger-api-gateway-build
```

Serve the generated `swagger.json` through the pinned Swagger UI container:

```bash
cd ofm-infra
just swagger-api-gateway-serve
```

Stop the Swagger UI container:

```bash
cd ofm-infra
just swagger-api-gateway-down
```

Swagger UI is exposed on:

- `http://localhost:8082`

## gRPC Docs

Local gRPC/proto documentation is generated from `ofm-common/proto` with
`grpc-docs` and served as a static site.

Build the gRPC docs:

```bash
cd ofm-infra
just grpc-docs-build
```

Build and serve the generated site:

```bash
cd ofm-infra
just grpc-docs-serve
```

Stop the gRPC docs preview container:

```bash
cd ofm-infra
just grpc-docs-down
```

The generated files are written to:

- `ofm-docs/grpc`

The preview UI is exposed on:

- `http://localhost:8083`

## SonarQube

SonarQube is available as optional local infra for code quality and coverage
reporting. It is intentionally separate from the default `infra-all` stack so
normal local startup does not pay the SonarQube cost.

Start SonarQube:

```bash
cd ofm-infra
just sonarqube-up
```

Check container state or logs:

```bash
cd ofm-infra
just sonarqube-ps
just sonarqube-logs
```

Stop it:

```bash
cd ofm-infra
just sonarqube-down
```

The local UI is exposed on:

- `http://localhost:9005`

### Project model

Each Go repository is scanned as a separate SonarQube project. That keeps
service ownership and coverage reporting aligned with the repository layout.

Local scan commands:

```bash
cd ofm-infra
just sonarqube-scan-common
just sonarqube-scan-api-gateway
just sonarqube-scan-auth-service
just sonarqube-scan-user-service
just sonarqube-scan-mail-service
just sonarqube-scan-registration-saga-service
```

Or scan all Go repos together:

```bash
cd ofm-infra
just sonarqube-scan-all
```

### How scanning works

- each scan runs `go test ./...` with coverage in the target repo
- the generated `coverage.out` is passed into SonarQube
- generated protobuf files are excluded from analysis
- each repo is reported as its own SonarQube project

The scanner uses a SonarQube user token. Keep it in `ofm-infra/.env` as:

- `SONAR_TOKEN=...`

You can also override scan configuration with environment variables when needed:

- `SONARQUBE_URL`
- `SONARQUBE_DOCKER_NETWORK`
