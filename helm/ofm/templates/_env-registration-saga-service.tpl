{{- define "ofm.serviceEnv.registration-saga-service" -}}
{{- $host := include "ofm.externalHost" . -}}
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: NATS_URL
  value: nats://{{ include "ofm.natsHost" . }}:4222
- name: NATS_USER
  value: ""
- name: NATS_PASSWORD
  value: ""
- name: SCYLLA_HOSTS
  value: {{ $host }}
- name: SCYLLA_PORT
  value: "9042"
- name: SCYLLA_KEYSPACE
  value: registration_saga_service
- name: SCYLLA_USERNAME
  value: admin
- name: SCYLLA_PASSWORD
  value: admin
- name: SCYLLA_CONSISTENCY
  value: quorum
- name: SCYLLA_CONNECT_TIMEOUT
  value: 10s
- name: SCYLLA_MAX_WAIT_SCHEMA_AGREEMENT
  value: 30s
- name: SCYLLA_RETRY_ATTEMPTS
  value: "20"
- name: SCYLLA_RETRY_BACKOFF
  value: 2s
- name: NATS_STREAM_REGISTRATION_EVENTS
  value: REGISTRATION_EVENTS
- name: NATS_STREAM_USER_EVENTS
  value: USER_EVENTS
- name: NATS_STREAM_AUTH_EVENTS
  value: AUTH_EVENTS
- name: NATS_STREAM_MAIL_EVENTS
  value: MAIL_EVENTS
- name: NATS_SUBJECT_REGISTRATION_CODE_SENT
  value: registration.code.sent
- name: NATS_SUBJECT_REGISTRATION_COMPLETED
  value: registration.completed
- name: NATS_SUBJECT_REGISTRATION_FAILED
  value: registration.failed
- name: NATS_SUBJECT_SAGA_CREATE_USER
  value: saga.user.create
- name: NATS_SUBJECT_SAGA_CREATE_USER_RESULT
  value: saga.user.create.result
- name: NATS_SUBJECT_SAGA_CREATE_PENDING_AUTH
  value: saga.auth.create_pending_registration
- name: NATS_SUBJECT_SAGA_CREATE_PENDING_AUTH_RESULT
  value: saga.auth.create_pending_registration.result
- name: NATS_SUBJECT_MAIL_SEND_RESULT
  value: mail.send.result
- name: NATS_DURABLE_SAGA_CREATE_USER_RESULT
  value: registration_saga_user_create_result
- name: NATS_DURABLE_SAGA_CREATE_PENDING_AUTH_RESULT
  value: registration_saga_auth_create_pending_result
- name: NATS_DURABLE_MAIL_SEND_RESULT
  value: registration_saga_mail_send_result
- name: NATS_RESULT_BATCH_SIZE
  value: "32"
- name: NATS_RESULT_MAX_WAIT
  value: 10ms
- name: NATS_RESULT_WORKERS
  value: "8"
- name: NATS_RESULT_QUEUE_SIZE
  value: "500"
- name: NATS_RESULT_ACK_WAIT
  value: 30s
- name: NATS_RESULT_MAX_DELIVER
  value: "5"
- name: NATS_RESULT_ADAPTIVE_ENABLED
  value: "false"
- name: NATS_RESULT_ADAPTIVE_CHECK_INTERVAL
  value: 2s
- name: NATS_RESULT_ADAPTIVE_MEDIUM_PENDING
  value: "200"
- name: NATS_RESULT_ADAPTIVE_HIGH_PENDING
  value: "1000"
- name: NATS_RESULT_ADAPTIVE_LOW_BATCH_SIZE
  value: "8"
- name: NATS_RESULT_ADAPTIVE_LOW_MAX_WAIT
  value: 25ms
- name: NATS_RESULT_ADAPTIVE_MEDIUM_BATCH_SIZE
  value: "32"
- name: NATS_RESULT_ADAPTIVE_MEDIUM_MAX_WAIT
  value: 10ms
- name: NATS_RESULT_ADAPTIVE_HIGH_BATCH_SIZE
  value: "128"
- name: NATS_RESULT_ADAPTIVE_HIGH_MAX_WAIT
  value: 2ms
- name: AUTH_SERVICE_ADDRESS
  value: auth-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9501
- name: USER_SERVICE_ADDRESS
  value: user-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9502
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9500"
- name: METRICS_PORT
  value: "9600"
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
