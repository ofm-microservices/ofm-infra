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
- `order-saga-service-scylla`
- `order-service-yugabyte`
- `order-service-redis`
- `payment-service-yugabyte`
- `payment-service-redis`

## Compose

The stack is split across dedicated Compose files:

- `docker-compose.nats.yaml`
- `docker-compose.user-service.yaml`
- `docker-compose.auth-service.yaml`
- `docker-compose.registration-saga-service.yaml`
- `docker-compose.order-saga-service.yaml`
- `docker-compose.order-service.yaml`
- `docker-compose.payment-service.yaml`

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

### Stripe onboarding helper

Print the freelancer onboarding URL returned by the gateway:

```bash
JWT_TOKEN=... just payment-onboarding-flow
```

### Payment flow

Bring up only the payment stack infrastructure:

```bash
just payment-infra-up
```

## K3s + Helm + Linkerd

The k3s path runs the app stack as Helm-managed Kubernetes workloads with Linkerd sidecars.

### What it uses

- `k3s` for the local cluster
- `Helm` for the app release
- `Linkerd` for mTLS and traffic policy
- Kubernetes `Service` DNS for discovery between services

### How to run

```bash
cd ofm-infra
just k3s-up
```

This builds/imports the app images into k3s, labels the app namespace for Linkerd injection, and installs the umbrella Helm release.

Stop the release with:

```bash
cd ofm-infra
just k3s-down
```

### Service discovery model

In Kubernetes, services talk to each other through stable service DNS names instead of localhost or pod IPs.

Examples:

- `auth-service.ofm.svc.cluster.local:9501`
- `user-service.ofm.svc.cluster.local:9502`
- `gig-service.ofm.svc.cluster.local:9503`
- `file-service.ofm.svc.cluster.local:9504`
- `order-service.ofm.svc.cluster.local:9505`
- `payment-service.ofm.svc.cluster.local:9506`
- `registration-saga-service.ofm.svc.cluster.local:9500`
- `order-saga-service.ofm.svc.cluster.local:9507`

The Helm chart injects these addresses into pod env so scaling replicas later does not change the callers.

### Linkerd note

The chart labels the app namespace with `linkerd.io/inject=enabled`. Make sure the Linkerd control plane is already installed in the cluster before running `just k3s-up`.

## Tooling

This repo currently uses:

- `Docker Compose`
- `Just`
- `AsyncAPI CLI`
- `pkgsite`
- `swaggerapi/swagger-ui`
- `grpc-docs`
- `SonarQube`

## Notes

- Compose remains the source of truth for third-party infra containers and must be started separately.
- Service environment variables remain in the service-local `.env` files.

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
just sonarqube-scan-file-service
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
