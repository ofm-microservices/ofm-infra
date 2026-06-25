set shell := ["zsh", "-cu"]
set dotenv-load := true

compose := "docker compose -f docker-compose.nats.yaml -f docker-compose.user-service.yaml -f docker-compose.auth-service.yaml -f docker-compose.gig-service.yaml -f docker-compose.registration-saga-service.yaml -f docker-compose.order-saga-service.yaml -f docker-compose.order-service.yaml -f docker-compose.payment-service.yaml -f docker-compose.review-service.yaml -f docker-compose.search-service.yaml -f docker-compose.file-service.yaml"
asyncapi_compose := "docker compose -f docker-compose.asyncapi.yaml"
swagger_compose := "docker compose -f docker-compose.swagger.yaml"
grpc_docs_compose := "docker compose -f docker-compose.grpc-docs.yaml"
sonarqube_compose := "docker compose -f docker-compose.sonarqube.yaml"

infra-up:
    {{compose}} up -d --remove-orphans
    bash ./scripts/infra-up.sh

infra-all:
    {{compose}} up -d --force-recreate --remove-orphans

infra-down:
    {{compose}} down --remove-orphans

infra-volumes-delete-all:
    test "$CONFIRM_DELETE_OFM_VOLUMES" = "yes"
    {{compose}} down -v --remove-orphans
    {{asyncapi_compose}} down -v --remove-orphans
    {{swagger_compose}} down -v --remove-orphans
    {{grpc_docs_compose}} down -v --remove-orphans
    {{sonarqube_compose}} down -v --remove-orphans

file-service-up:
    {{compose}} up -d file-service-scylla file-service-scylla-init file-service-rustfs

file-service-down:
    {{compose}} stop file-service-scylla file-service-rustfs

file-service-logs:
    {{compose}} logs -f file-service-scylla file-service-rustfs

file-service-ps:
    {{compose}} ps file-service-scylla file-service-rustfs

file-service-port-forward:
    source ./scripts/file-service-port-forward.sh && ofm_file_service_port_forward_start

file-service-port-forward-stop:
    source ./scripts/file-service-port-forward.sh && ofm_file_service_port_forward_cleanup

infra-logs:
    {{compose}} logs -f

infra-ps:
    {{compose}} ps

registration-flow:
    bash ./scripts/registration-flow.sh

registration-infra-up:
    bash ./scripts/registration-infra-up.sh

gig-flow *args:
    bash ./scripts/gig-flow.sh {{args}}

order-flow *args:
    bash ./scripts/order-flow.sh {{args}}

order-complete-flow *args:
    bash ./scripts/order-complete-flow.sh {{args}}

review-flow *args:
    bash ./scripts/review-flow.sh {{args}}

order-infra-up:
    bash ./scripts/order-infra-up.sh

order-infra-down:
    {{compose}} stop nats order-saga-service-scylla order-service-redis order-service-yugabyte payment-service-redis payment-service-yugabyte file-service-scylla file-service-rustfs

order-infra-logs:
    {{compose}} logs -f nats order-saga-service-scylla order-service-redis order-service-yugabyte payment-service-redis payment-service-yugabyte file-service-scylla file-service-rustfs

order-infra-ps:
    {{compose}} ps nats order-saga-service-scylla order-service-redis order-service-yugabyte payment-service-redis payment-service-yugabyte file-service-scylla file-service-rustfs

gig-infra-up:
    bash ./scripts/gig-infra-up.sh

gig-infra-down:
    {{compose}} stop nats gig-service-redis gig-service-yugabyte payment-service-redis payment-service-yugabyte file-service-scylla file-service-rustfs

gig-infra-logs:
    {{compose}} logs -f nats gig-service-redis gig-service-yugabyte payment-service-redis payment-service-yugabyte file-service-scylla file-service-rustfs

gig-infra-ps:
    {{compose}} ps nats gig-service-redis gig-service-yugabyte payment-service-redis payment-service-yugabyte file-service-scylla file-service-rustfs

payment-onboarding-flow:
    bash ./scripts/payment-onboarding-flow.sh

payment-onboarding-token:
    bash ./scripts/payment-onboarding-token.sh

payment-infra-up:
    bash ./scripts/payment-infra-up.sh

payment-webhook-ngrok:
    ingress_ip="$(kubectl --kubeconfig "$HOME/.kube/k3d-ofm.yaml" -n ofm get ingress payment-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')" && test -n "$ingress_ip" && ngrok http --host-header=payment.ofm.local "$ingress_ip:80"

payment-infra-down:
    {{compose}} stop nats payment-service-redis payment-service-yugabyte

payment-infra-logs:
    {{compose}} logs -f nats payment-service-redis payment-service-yugabyte

payment-infra-ps:
    {{compose}} ps nats payment-service-redis payment-service-yugabyte

k3d-up:
    bash ./scripts/k3d-up.sh

k3s-up:
    bash ./scripts/k3d-up.sh

k3d-build-images service="all":
    bash ./scripts/k3d-build-images.sh {{service}}

k3s-build-images service="all":
    bash ./scripts/k3d-build-images.sh {{service}}

k3d-build-up:
    bash ./scripts/k3d-build-images.sh && bash ./scripts/k3d-import-images.sh && OFM_K3D_IMPORT=0 bash ./scripts/k3d-up.sh

k3s-build-up:
    bash ./scripts/k3s-build-images.sh && bash ./scripts/k3s-import-images.sh && bash ./scripts/k3s-up.sh

k3d-import-images:
    bash ./scripts/k3d-import-images.sh

k3s-import-images:
    bash ./scripts/k3d-import-images.sh

k3d-restart-service service:
    bash ./scripts/k3d-restart-service.sh {{service}}

k3d-down:
    bash ./scripts/k3d-down.sh

k3s-down:
    bash ./scripts/k3d-down.sh

k3d-stop:
    bash ./scripts/k3d-stop.sh

k3s-stop:
    bash ./scripts/k3d-stop.sh

open-k3s-ports:
    bash ./scripts/open-k3s-ports.sh

asyncapi-docs-validate:
    {{asyncapi_compose}} run --rm asyncapi-validate

asyncapi-docs-build:
    just asyncapi-docs-validate

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
    {{grpc_docs_compose}} up -d --force-recreate grpc-docs-generate

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

sonarqube-up:
    {{sonarqube_compose}} up -d

sonarqube-down:
    {{sonarqube_compose}} down

sonarqube-volumes-delete:
    test "$CONFIRM_DELETE_OFM_VOLUMES" = "yes"
    docker volume rm \
        ofm-infra_sonarqube_postgres_data \
        ofm-infra_sonarqube_data \
        ofm-infra_sonarqube_extensions \
        ofm-infra_sonarqube_logs 2>/dev/null || true

sonarqube-logs:
    {{sonarqube_compose}} logs -f

sonarqube-ps:
    {{sonarqube_compose}} ps

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

sonarqube-scan-review-service:
    just sonarqube-scan ofm-review-service ofm-review-service "OFM Review Service"

sonarqube-scan-gig-service:
    just sonarqube-scan ofm-gig-service ofm-gig-service "OFM Gig Service"

sonarqube-scan-order-service:
    just sonarqube-scan ofm-order-service ofm-order-service "OFM Order Service"

sonarqube-scan-mail-service:
    just sonarqube-scan ofm-mail-service ofm-mail-service "OFM Mail Service"

go-lint-all:
    for repo in ../ofm-common ../ofm-api-gateway ../ofm-auth-service ../ofm-user-service ../ofm-file-service ../ofm-gig-service ../ofm-review-service ../ofm-order-service ../ofm-order-saga-service ../ofm-payment-service ../ofm-registration-saga-service ../ofm-search-service ../ofm-mail-service; do \
        (cd "$repo" && GOCACHE=/tmp/gocache go run github.com/golangci/golangci-lint/cmd/golangci-lint@v1.64.8 run ./...); \
    done

sonarqube-scan-registration-saga-service:
    just sonarqube-scan ofm-registration-saga-service ofm-registration-saga-service "OFM Registration Saga Service"

sonarqube-scan-order-saga-service:
    just sonarqube-scan ofm-order-saga-service ofm-order-saga-service "OFM Order Saga Service"

sonarqube-scan-all:
    just sonarqube-scan-common
    just sonarqube-scan-api-gateway
    just sonarqube-scan-auth-service
    just sonarqube-scan-user-service
    just sonarqube-scan-file-service
    just sonarqube-scan-review-service
    just sonarqube-scan-gig-service
    just sonarqube-scan-order-service
    just sonarqube-scan-mail-service
    just sonarqube-scan-registration-saga-service
    just sonarqube-scan-order-saga-service

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

sonarqube-coverage-analysis-review-service:
    just sonarqube-coverage-analysis ofm-review-service ofm-review-service

sonarqube-coverage-analysis-gig-service:
    just sonarqube-coverage-analysis ofm-gig-service ofm-gig-service

sonarqube-coverage-analysis-order-service:
    just sonarqube-coverage-analysis ofm-order-service ofm-order-service

sonarqube-coverage-analysis-user-service-all:
    just sonarqube-coverage-analysis-all ofm-user-service ofm-user-service

sonarqube-coverage-analysis-mail-service:
    just sonarqube-coverage-analysis ofm-mail-service ofm-mail-service

sonarqube-coverage-analysis-registration-saga-service:
    just sonarqube-coverage-analysis-all ofm-registration-saga-service ofm-registration-saga-service

sonarqube-coverage-analysis-order-saga-service:
    just sonarqube-coverage-analysis-all ofm-order-saga-service ofm-order-saga-service

sonarqube-coverage-analysis-order-saga-service-all:
    just sonarqube-coverage-analysis-all ofm-order-saga-service ofm-order-saga-service

sonarqube-coverage-analysis-registration-saga-service-all:
    just sonarqube-coverage-analysis-all ofm-registration-saga-service ofm-registration-saga-service
