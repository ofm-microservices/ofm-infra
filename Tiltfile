version_settings(constraint='>=0.33.0')

local_resource(
    'registration-saga-service',
    serve_cmd='cd ../ofm-registration-saga-service && export GOCACHE=/tmp/ofm-registration-saga-service-gocache && export NATS_URL=nats://127.0.0.1:4222 && export SCYLLA_HOSTS=127.0.0.1 && export AUTH_SERVICE_ADDRESS=127.0.0.1:9091 && export USER_SERVICE_ADDRESS=127.0.0.1:9092 && exec go run ./cmd/registration-saga-service',
    deps=['../ofm-registration-saga-service', '../ofm-common'],
    labels=['app', 'registration-saga-service'],
)

local_resource(
    'gig-service',
    serve_cmd='cd ../ofm-gig-service && export GOCACHE=/tmp/ofm-gig-service-gocache && export NATS_URL=nats://127.0.0.1:4222 && export DB_HOST=127.0.0.1 && export DB_PORT=5435 && export DB_USER=admin && export DB_PASSWORD=admin && export DB_NAME=gig_service && export REDIS_HOST=127.0.0.1 && export REDIS_PORT=6380 && export FILE_SERVICE_ADDRESS=127.0.0.1:9096 && exec go run ./cmd/gig-service',
    deps=['../ofm-gig-service', '../ofm-common'],
    labels=['app', 'gig-service'],
)

local_resource(
    'file-service',
    serve_cmd='cd ../ofm-file-service && export GOCACHE=/tmp/ofm-file-service-gocache && export APP_ENV=local && export LOG_LEVEL=info && export GRPC_HOST=0.0.0.0 && export GRPC_PORT=9096 && export SCYLLA_HOSTS=127.0.0.1 && export SCYLLA_PORT=9043 && export SCYLLA_KEYSPACE=file_service && export SCYLLA_USERNAME=admin && export SCYLLA_PASSWORD=admin && export REDIS_HOST=127.0.0.1 && export REDIS_PORT=6381 && export RUSTFS_ENDPOINT=http://127.0.0.1:9006 && export RUSTFS_ACCESS_KEY=rustfsadmin && export RUSTFS_SECRET_KEY=rustfsadmin && export RUSTFS_BUCKET=ofm-files && exec go run ./cmd/file-service',
    deps=['../ofm-file-service', '../ofm-common'],
    labels=['app', 'file-service'],
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
    serve_cmd='cd ../ofm-api-gateway && export GOCACHE=/tmp/ofm-api-gateway-gocache && export NATS_URL=nats://127.0.0.1:4222 && export REGISTRATION_SAGA_ADDRESS=127.0.0.1:9090 && export AUTH_SERVICE_ADDRESS=127.0.0.1:9091 && export GIG_SERVICE_ADDRESS=127.0.0.1:9093 && exec go run ./cmd/api-gateway',
    deps=['../ofm-api-gateway', '../ofm-common'],
    labels=['app', 'api-gateway'],
)
