{{- define "ofm.serviceEnv.gig-service" -}}
{{- $host := include "ofm.externalHost" . -}}
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: DB_HOST
  value: {{ $host }}
- name: DB_PORT
  value: "5435"
- name: DB_USER
  value: admin
- name: DB_PASSWORD
  value: admin
- name: DB_NAME
  value: gig_service
- name: REDIS_HOST
  value: {{ $host }}
- name: REDIS_PORT
  value: "6380"
- name: REDIS_PASSWORD
  value: ""
- name: REDIS_DB
  value: "0"
- name: NATS_URL
  value: nats://{{ include "ofm.natsHost" . }}:4222
- name: NATS_USER
  value: ""
- name: NATS_PASSWORD
  value: ""
- name: NATS_STREAM_GIG_EVENTS
  value: GIG_EVENTS
- name: NATS_STREAM_SAGA_COMMANDS
  value: SAGA_GIG_COMMANDS
- name: NATS_SUBJECT_GIG_CREATED
  value: gig.created
- name: NATS_SUBJECT_GIG_PUBLISHED
  value: gig.published
- name: NATS_SUBJECT_GIG_PREVIEW_PROJECTION
  value: gig.preview.projection.requested
- name: NATS_SUBJECT_GIG_VIEWED
  value: gig.viewed
- name: NATS_SUBJECT_GIG_DELETED
  value: gig.deleted
- name: NATS_SUBJECT_SAGA_CREATE_GIG
  value: saga.gig.create
- name: NATS_SUBJECT_SAGA_CREATE_GIG_RESULT
  value: saga.gig.create.result
- name: NATS_SUBJECT_SAGA_PUBLISH_GIG
  value: saga.gig.publish
- name: NATS_SUBJECT_SAGA_PUBLISH_GIG_RESULT
  value: saga.gig.publish.result
- name: NATS_DURABLE_SAGA_CREATE_GIG
  value: gig_service_saga_create
- name: NATS_DURABLE_SAGA_PUBLISH_GIG
  value: gig_service_saga_publish
- name: NATS_DURABLE_GIG_PREVIEW_PROJECTION
  value: gig_service_gig_preview_projection
- name: NATS_SAGA_BATCH_SIZE
  value: "32"
- name: NATS_SAGA_MAX_WAIT
  value: 10ms
- name: NATS_SAGA_WORKERS
  value: "8"
- name: NATS_SAGA_QUEUE_SIZE
  value: "500"
- name: NATS_SAGA_ACK_WAIT
  value: 30s
- name: NATS_SAGA_MAX_DELIVER
  value: "5"
- name: NATS_SAGA_ADAPTIVE_ENABLED
  value: "false"
- name: NATS_SAGA_ADAPTIVE_CHECK_INTERVAL
  value: 2s
- name: NATS_SAGA_ADAPTIVE_MEDIUM_PENDING
  value: "200"
- name: NATS_SAGA_ADAPTIVE_HIGH_PENDING
  value: "1000"
- name: NATS_SAGA_ADAPTIVE_LOW_BATCH_SIZE
  value: "8"
- name: NATS_SAGA_ADAPTIVE_LOW_MAX_WAIT
  value: 25ms
- name: NATS_SAGA_ADAPTIVE_MEDIUM_BATCH_SIZE
  value: "32"
- name: NATS_SAGA_ADAPTIVE_MEDIUM_MAX_WAIT
  value: 10ms
- name: NATS_SAGA_ADAPTIVE_HIGH_BATCH_SIZE
  value: "128"
- name: NATS_SAGA_ADAPTIVE_HIGH_MAX_WAIT
  value: 2ms
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
- name: FILE_SERVICE_ADDRESS
  value: file-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9504
- name: PAYMENT_SERVICE_ADDRESS
  value: payment-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9506
- name: USER_SERVICE_ADDRESS
  value: user-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9502
- name: CLICKHOUSE_ENDPOINT
  value: http://clickhouse.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:8123
- name: CLICKHOUSE_USER
  value: admin
- name: CLICKHOUSE_PASSWORD
  value: admin
- name: CLICKHOUSE_DATABASE
  value: default
- name: CLICKHOUSE_TABLE
  value: ofm_business_events
- name: CLICKHOUSE_REFRESH_PERIOD
  value: 5m
- name: GIG_PREVIEW_PAGE_SIZE
  value: "10"
- name: GIG_PREVIEW_WINDOW_SIZE
  value: "100"
- name: GIG_PREVIEW_WINDOW_TTL
  value: 5m
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9503"
- name: METRICS_PORT
  value: "9603"
{{- end -}}
