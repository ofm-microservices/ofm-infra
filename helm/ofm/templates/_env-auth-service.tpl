{{- define "ofm.serviceEnv.auth-service" -}}
{{- $host := include "ofm.externalHost" . -}}
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: DB_HOST
  value: {{ $host }}
- name: DB_PORT
  value: "5434"
- name: DB_USER
  value: admin
- name: DB_PASSWORD
  value: admin
- name: DB_NAME
  value: auth_service
- name: NATS_URL
  value: nats://{{ include "ofm.natsHost" . }}:4222
- name: NATS_USER
  value: ""
- name: NATS_PASSWORD
  value: ""
- name: NATS_STREAM_AUTH_EVENTS
  value: AUTH_EVENTS
- name: NATS_STREAM_MAIL_COMMANDS
  value: MAIL_COMMANDS
- name: NATS_STREAM_SAGA_COMMANDS
  value: SAGA_AUTH_COMMANDS
- name: NATS_SUBJECT_AUTH_CREATED
  value: auth.created
- name: NATS_SUBJECT_SAGA_CREATE_PENDING_AUTH
  value: saga.auth.create_pending_registration
- name: NATS_SUBJECT_SAGA_DELETE_AUTH
  value: saga.auth.delete
- name: NATS_SUBJECT_SAGA_CREATE_PENDING_AUTH_RESULT
  value: saga.auth.create_pending_registration.result
- name: NATS_SUBJECT_SAGA_DELETE_AUTH_RESULT
  value: saga.auth.delete.result
- name: NATS_SUBJECT_MAIL_SEND
  value: mail.send
- name: NATS_DURABLE_SAGA_CREATE_AUTH
  value: auth_service_saga_create_pending_registration
- name: NATS_DURABLE_SAGA_DELETE_AUTH
  value: auth_service_saga_delete
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
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9501"
- name: METRICS_PORT
  value: "9601"
- name: JWT_ACCESS_SECRET
  value: aa96fae1a6eee39b879dad6b6bb372e63278257bf9f94010bc7d25693f61e38c
- name: JWT_REFRESH_SECRET
  value: 0f91f8d603f2f8d70b7b5e04b57c0b7d4e3e0e1ce25a2d24f7b3c1b8a7b7f5a2
- name: JWT_ISSUER
  value: ofm-auth-service
- name: JWT_ACCESS_TOKEN_TTL
  value: 15m
- name: JWT_REFRESH_TOKEN_TTL
  value: 720h
- name: JWT_REFRESH_TOKEN_BYTES
  value: "32"
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
