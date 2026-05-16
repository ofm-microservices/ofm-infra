version_settings(constraint='>=0.33.0')

def parse_env_file(path):
    data = {}
    for raw in str(read_file(path)).split("\n"):
        line = raw.strip()
        if not line or line.startswith("#") or line.find("=") < 0:
            continue
        key, value = line.split("=", 1)
        data[key.strip()] = value.strip()
    return data

payment_env = parse_env_file("../ofm-payment-service/.env")
api_gateway_env = parse_env_file("../ofm-api-gateway/.env")

local_resource(
    'registration-saga-service',
    serve_cmd='cd ../ofm-registration-saga-service && export GOCACHE=/tmp/ofm-registration-saga-service-gocache && export NATS_URL=nats://127.0.0.1:4222 && export SCYLLA_HOSTS=127.0.0.1 && export AUTH_SERVICE_ADDRESS=127.0.0.1:9501 && export USER_SERVICE_ADDRESS=127.0.0.1:9502 && export METRICS_PORT=9600 && exec go run ./cmd/registration-saga-service',
    deps=['../ofm-registration-saga-service', '../ofm-common'],
    labels=['app', 'registration-saga-service'],
)

local_resource(
    'gig-service',
    serve_cmd='cd ../ofm-gig-service && export GOCACHE=/tmp/ofm-gig-service-gocache && export NATS_URL=nats://127.0.0.1:4222 && export DB_HOST=127.0.0.1 && export DB_PORT=5435 && export DB_USER=admin && export DB_PASSWORD=admin && export DB_NAME=gig_service && export REDIS_HOST=127.0.0.1 && export REDIS_PORT=6380 && export FILE_SERVICE_ADDRESS=127.0.0.1:9504 && export METRICS_PORT=9603 && exec go run ./cmd/gig-service',
    deps=['../ofm-gig-service', '../ofm-common'],
    labels=['app', 'gig-service'],
)

local_resource(
    'file-service',
    serve_cmd='cd ../ofm-file-service && export GOCACHE=/tmp/ofm-file-service-gocache && export APP_ENV=local && export LOG_LEVEL=info && export GRPC_HOST=0.0.0.0 && export GRPC_PORT=9504 && export SCYLLA_HOSTS=127.0.0.1 && export SCYLLA_PORT=9043 && export SCYLLA_KEYSPACE=file_service && export SCYLLA_USERNAME=admin && export SCYLLA_PASSWORD=admin && export REDIS_HOST=127.0.0.1 && export REDIS_PORT=6381 && export RUSTFS_ENDPOINT=http://127.0.0.1:9006 && export RUSTFS_ACCESS_KEY=rustfsadmin && export RUSTFS_SECRET_KEY=rustfsadmin && export RUSTFS_BUCKET=ofm-files && export METRICS_PORT=9604 && exec go run ./cmd/file-service',
    deps=['../ofm-file-service', '../ofm-common'],
    labels=['app', 'file-service'],
)

local_resource(
    'payment-service',
    serve_cmd='cd ../ofm-payment-service && export GOCACHE=/tmp/ofm-payment-service-gocache && export APP_ENV=local && export LOG_LEVEL=info && export HTTP_HOST=0.0.0.0 && export HTTP_PORT=8081 && export GRPC_HOST=0.0.0.0 && export GRPC_PORT=9506 && export NATS_URL=nats://127.0.0.1:4222 && export DB_HOST=127.0.0.1 && export DB_PORT=5436 && export DB_USER=admin && export DB_PASSWORD=admin && export DB_NAME=payment_service && export REDIS_HOST=127.0.0.1 && export REDIS_PORT=6381 && export STRIPE_SECRET_KEY=%s && export STRIPE_FREELANCER_ONBOARDING_WEBHOOK_SECRET=%s && export STRIPE_CONNECT_RETURN_URL=%s && export STRIPE_CONNECT_REFRESH_URL=%s && export STRIPE_CONNECT_COUNTRY=US && export METRICS_PORT=9609 && exec go run ./cmd/payment-service' % (payment_env.get("STRIPE_SECRET_KEY", ""), payment_env.get("STRIPE_FREELANCER_ONBOARDING_WEBHOOK_SECRET", ""), payment_env.get("STRIPE_CONNECT_RETURN_URL", ""), payment_env.get("STRIPE_CONNECT_REFRESH_URL", "")),
    deps=['../ofm-payment-service', '../ofm-common'],
    labels=['app', 'payment-service'],
)

local_resource(
    'auth-service',
    serve_cmd='cd ../ofm-auth-service && export GOCACHE=/tmp/ofm-auth-service-gocache && export NATS_URL=nats://127.0.0.1:4222 && export DB_HOST=127.0.0.1 && export DB_PORT=5434 && export METRICS_PORT=9601 && exec go run ./cmd/auth-service',
    deps=['../ofm-auth-service', '../ofm-common'],
    labels=['app', 'auth-service'],
)

local_resource(
    'user-service',
    serve_cmd='cd ../ofm-user-service && export GOCACHE=/tmp/ofm-user-service-gocache && export NATS_URL=nats://127.0.0.1:4222 && export DB_HOST=127.0.0.1 && export REDIS_HOST=127.0.0.1 && export METRICS_PORT=9602 && exec go run ./cmd/user-service',
    deps=['../ofm-user-service', '../ofm-common'],
    labels=['app', 'user-service'],
)

local_resource(
    'mail-service',
    serve_cmd='cd ../ofm-mail-service && export GOCACHE=/tmp/ofm-mail-service-gocache && export NATS_URL=nats://127.0.0.1:4222 && export METRICS_PORT=9605 && exec go run ./cmd/mail-service',
    deps=['../ofm-mail-service', '../ofm-common'],
    labels=['app', 'mail-service'],
)

local_resource(
    'api-gateway',
    serve_cmd='cd ../ofm-api-gateway && export GOCACHE=/tmp/ofm-api-gateway-gocache && export NATS_URL=nats://127.0.0.1:4222 && export REGISTRATION_SAGA_ADDRESS=127.0.0.1:9500 && export AUTH_SERVICE_ADDRESS=127.0.0.1:9501 && export GIG_SERVICE_ADDRESS=127.0.0.1:9503 && export PAYMENT_SERVICE_ADDRESS=127.0.0.1:9506 && export JWT_SECRET=%s && export METRICS_PORT=9606 && exec go run ./cmd/api-gateway' % api_gateway_env.get("JWT_SECRET", ""),
    deps=['../ofm-api-gateway', '../ofm-common'],
    labels=['app', 'api-gateway'],
)
