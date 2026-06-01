{{- define "ofm.serviceEnv.user-service" -}}
{{- $host := include "ofm.externalHost" . -}}
{{- $useHostDbBridge := default false .Values.global.hostDbBridge.enabled -}}
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: DB_HOST
{{- if $useHostDbBridge }}
  value: host-db-bridge
{{- else }}
  value: {{ $host }}
{{- end }}
- name: DB_PORT
  value: "5433"
- name: DB_USER
  value: admin
- name: DB_PASSWORD
  value: admin
- name: DB_NAME
  value: user_service
- name: REDIS_HOST
  value: {{ $host }}
- name: REDIS_PORT
  value: "6379"
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
- name: NATS_STREAM_USER_EVENTS
  value: USER_EVENTS
- name: NATS_STREAM_SAGA_COMMANDS
  value: SAGA_USER_COMMANDS
- name: NATS_SUBJECT_USER_CREATED
  value: user.created
- name: NATS_SUBJECT_SAGA_CREATE_USER
  value: saga.user.create
- name: NATS_SUBJECT_SAGA_DELETE_USER
  value: saga.user.delete
- name: NATS_SUBJECT_SAGA_CREATE_USER_RESULT
  value: saga.user.create.result
- name: NATS_SUBJECT_SAGA_DELETE_USER_RESULT
  value: saga.user.delete.result
- name: NATS_DURABLE_SAGA_CREATE_USER
  value: user_service_saga_create
- name: NATS_DURABLE_SAGA_DELETE_USER
  value: user_service_saga_delete
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
- name: FILE_SERVICE_ADDRESS
  value: file-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9504
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9502"
- name: METRICS_PORT
  value: "9602"
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
