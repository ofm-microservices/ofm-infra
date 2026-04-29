version_settings(constraint='>=0.33.0')

local_resource(
    'registration-saga-service',
    serve_cmd='cd ../ofm-registration-saga-service && export GOCACHE=/tmp/ofm-registration-saga-service-gocache && export NATS_URL=nats://127.0.0.1:4222 && export SCYLLA_HOSTS=127.0.0.1 && exec go run ./cmd/registration-saga-service',
    deps=['../ofm-registration-saga-service', '../ofm-common'],
    labels=['app', 'registration-saga-service'],
)

local_resource(
    'auth-service',
    serve_cmd='cd ../ofm-auth-service && export GOCACHE=/tmp/ofm-auth-service-gocache && export NATS_URL=nats://127.0.0.1:4222 && export DB_HOST=127.0.0.1 && export DB_PORT=5434 && exec go run ./cmd/auth-service',
    deps=['../ofm-auth-service', '../ofm-common'],
    labels=['app', 'auth-service'],
)

local_resource(
    'user-service',
    serve_cmd='cd ../ofm-user-service && export GOCACHE=/tmp/ofm-user-service-gocache && export NATS_URL=nats://127.0.0.1:4222 && export DB_HOST=127.0.0.1 && export REDIS_HOST=127.0.0.1 && exec go run ./cmd/user-service',
    deps=['../ofm-user-service', '../ofm-common'],
    labels=['app', 'user-service'],
)

local_resource(
    'mail-service',
    serve_cmd='cd ../ofm-mail-service && export GOCACHE=/tmp/ofm-mail-service-gocache && export NATS_URL=nats://127.0.0.1:4222 && exec go run ./cmd/mail-service',
    deps=['../ofm-mail-service', '../ofm-common'],
    labels=['app', 'mail-service'],
)

local_resource(
    'api-gateway',
    serve_cmd='cd ../ofm-api-gateway && export GOCACHE=/tmp/ofm-api-gateway-gocache && export NATS_URL=nats://127.0.0.1:4222 && export REGISTRATION_SAGA_ADDRESS=127.0.0.1:9090 && exec go run ./cmd/api-gateway',
    deps=['../ofm-api-gateway', '../ofm-common'],
    labels=['app', 'api-gateway'],
)
