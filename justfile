set shell := ["zsh", "-cu"]
set dotenv-load := true

compose := "docker compose -f docker-compose.nats.yaml -f docker-compose.user-service.yaml -f docker-compose.auth-service.yaml -f docker-compose.gig-service.yaml -f docker-compose.registration-saga-service.yaml -f docker-compose.order-saga-service.yaml -f docker-compose.order-service.yaml -f docker-compose.payment-service.yaml -f docker-compose.file-service.yaml"
asyncapi_compose := "docker compose -f docker-compose.asyncapi.yaml"
swagger_compose := "docker compose -f docker-compose.swagger.yaml"
grpc_docs_compose := "docker compose -f docker-compose.grpc-docs.yaml"
sonarqube_compose := "docker compose -f docker-compose.sonarqube.yaml"
observability_compose := "docker compose -p ofm-observability -f docker-compose.observability.yaml"

infra-up:
    {{compose}} up -d --remove-orphans
    {{compose}} rm -fsv \
        payment-service-yugabyte-init

infra-all:
    {{compose}} up -d --force-recreate --remove-orphans

infra-down:
    {{compose}} down --remove-orphans

infra-volumes-delete-all:
    {{compose}} down -v --remove-orphans
    {{asyncapi_compose}} down -v --remove-orphans
    {{swagger_compose}} down -v --remove-orphans
    {{grpc_docs_compose}} down -v --remove-orphans
    {{sonarqube_compose}} down -v --remove-orphans

file-service-up:
    docker compose -f docker-compose.file-service.yaml up -d --remove-orphans

file-service-down:
    docker compose -f docker-compose.file-service.yaml down --remove-orphans

file-service-logs:
    docker compose -f docker-compose.file-service.yaml logs -f

file-service-ps:
    docker compose -f docker-compose.file-service.yaml ps

infra-logs:
    {{compose}} logs -f

infra-ps:
    {{compose}} ps

registration-flow:
    bash ./scripts/registration-flow.sh

gig-flow:
    bash ./scripts/gig-flow.sh

payment-onboarding-flow:
    bash ./scripts/payment-onboarding-flow.sh

payment-onboarding-token:
    bash ./scripts/payment-onboarding-token.sh

payment-infra-up:
    bash ./scripts/payment-infra-up.sh

payment-infra-down:
    docker compose -f docker-compose.nats.yaml -f docker-compose.payment-service.yaml down --remove-orphans

payment-infra-logs:
    docker compose -f docker-compose.nats.yaml -f docker-compose.payment-service.yaml logs -f

payment-infra-ps:
    docker compose -f docker-compose.nats.yaml -f docker-compose.payment-service.yaml ps

payment-tilt-up:
    tilt up payment-service api-gateway

payment-tilt-down:
    tilt down

asyncapi-docs-validate:
    {{asyncapi_compose}} run --rm asyncapi-validate

asyncapi-docs-build:
    {{asyncapi_compose}} run --rm asyncapi-generate

asyncapi-docs-serve:
    {{asyncapi_compose}} up -d --force-recreate asyncapi-preview

asyncapi-docs-down:
    {{asyncapi_compose}} down

godoc-serve:
    zsh ./scripts/pkgsite-serve.sh

godoc-html-build:
    zsh ./scripts/pkgsite-static.sh

buf-common-lint:
    cd ../ofm-common && just buf-lint

buf-common-generate:
    cd ../ofm-common && just proto-gen

grpc-docs-build:
    mkdir -p ../ofm-docs/grpc
    {{grpc_docs_compose}} run --rm grpc-docs-generate

grpc-docs-serve:
    just grpc-docs-build
    {{grpc_docs_compose}} up -d --force-recreate grpc-docs-preview

grpc-docs-down:
    {{grpc_docs_compose}} down

swagger-api-gateway-build:
    mkdir -p ../ofm-docs/swagger/api-gateway
    cd ../ofm-api-gateway && GOBIN=/tmp/ofm-bin go run github.com/swaggo/swag/cmd/swag@v1.16.4 init -g doc.go -d internal/presentation/http,internal/domain -o ../ofm-docs/swagger/api-gateway --parseInternal

swagger-api-gateway-serve:
    just swagger-api-gateway-build
    {{swagger_compose}} up -d --force-recreate api-gateway-swagger-ui

swagger-api-gateway-down:
    {{swagger_compose}} down

tilt-up:
    tilt up

tilt-down:
    tilt down

sonarqube-up:
    {{sonarqube_compose}} up -d

sonarqube-down:
    {{sonarqube_compose}} down

sonarqube-volumes-delete:
    docker volume rm \
        ofm-infra_sonarqube_postgres_data \
        ofm-infra_sonarqube_data \
        ofm-infra_sonarqube_extensions \
        ofm-infra_sonarqube_logs 2>/dev/null || true

sonarqube-logs:
    {{sonarqube_compose}} logs -f

sonarqube-ps:
    {{sonarqube_compose}} ps

observability-up:
    {{observability_compose}} up -d --remove-orphans

observability-down:
    docker compose -p ofm-observability -f docker-compose.observability.yaml down --remove-orphans

observability-logs:
    {{observability_compose}} logs -f

observability-ps:
    {{observability_compose}} ps

sonarqube-scan repo_dir project_key project_name:
    zsh ./scripts/sonarqube-scan.sh {{repo_dir}} {{project_key}} "{{project_name}}"

sonarqube-uncovered repo_dir project_key:
    zsh ./scripts/sonarqube-uncovered.sh {{repo_dir}} {{project_key}}

sonarqube-coverage-analysis repo_dir project_key:
    zsh ./scripts/sonarqube-coverage-analysis.sh {{repo_dir}} {{project_key}} --all

sonarqube-coverage-analysis-all repo_dir project_key:
    zsh ./scripts/sonarqube-coverage-analysis.sh {{repo_dir}} {{project_key}} --all

sonarqube-scan-common:
    just sonarqube-scan ofm-common ofm-common "OFM Common"

sonarqube-scan-api-gateway:
    just sonarqube-scan ofm-api-gateway ofm-api-gateway "OFM API Gateway"

sonarqube-scan-auth-service:
    just sonarqube-scan ofm-auth-service ofm-auth-service "OFM Auth Service"

sonarqube-scan-user-service:
    just sonarqube-scan ofm-user-service ofm-user-service "OFM User Service"

sonarqube-scan-file-service:
    just sonarqube-scan ofm-file-service ofm-file-service "OFM File Service"

sonarqube-scan-gig-service:
    just sonarqube-scan ofm-gig-service ofm-gig-service "OFM Gig Service"

sonarqube-scan-mail-service:
    just sonarqube-scan ofm-mail-service ofm-mail-service "OFM Mail Service"

sonarqube-scan-registration-saga-service:
    just sonarqube-scan ofm-registration-saga-service ofm-registration-saga-service "OFM Registration Saga Service"

sonarqube-scan-all:
    just sonarqube-scan-common
    just sonarqube-scan-api-gateway
    just sonarqube-scan-auth-service
    just sonarqube-scan-user-service
    just sonarqube-scan-file-service
    just sonarqube-scan-gig-service
    just sonarqube-scan-mail-service
    just sonarqube-scan-registration-saga-service

sonarqube-coverage-analysis-common:
    just sonarqube-coverage-analysis ofm-common ofm-common

sonarqube-coverage-analysis-api-gateway:
    just sonarqube-coverage-analysis ofm-api-gateway ofm-api-gateway

sonarqube-coverage-analysis-auth-service:
    just sonarqube-coverage-analysis ofm-auth-service ofm-auth-service

sonarqube-coverage-analysis-user-service:
    just sonarqube-coverage-analysis ofm-user-service ofm-user-service

sonarqube-coverage-analysis-file-service:
    just sonarqube-coverage-analysis ofm-file-service ofm-file-service

sonarqube-coverage-analysis-gig-service:
    just sonarqube-coverage-analysis ofm-gig-service ofm-gig-service

sonarqube-coverage-analysis-user-service-all:
    just sonarqube-coverage-analysis-all ofm-user-service ofm-user-service

sonarqube-coverage-analysis-mail-service:
    just sonarqube-coverage-analysis ofm-mail-service ofm-mail-service

sonarqube-coverage-analysis-registration-saga-service:
    just sonarqube-coverage-analysis-all ofm-registration-saga-service ofm-registration-saga-service

sonarqube-coverage-analysis-registration-saga-service-all:
    just sonarqube-coverage-analysis-all ofm-registration-saga-service ofm-registration-saga-service
