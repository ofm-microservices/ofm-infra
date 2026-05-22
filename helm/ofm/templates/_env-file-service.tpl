{{- define "ofm.serviceEnv.file-service" -}}
{{- $host := include "ofm.externalHost" . -}}
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: SCYLLA_HOSTS
  value: {{ $host }}
- name: SCYLLA_PORT
  value: "9043"
- name: SCYLLA_USERNAME
  value: admin
- name: SCYLLA_PASSWORD
  value: admin
- name: NATS_URL
  value: nats://{{ include "ofm.natsHost" . }}:4222
- name: NATS_USER
  value: ""
- name: NATS_PASSWORD
  value: ""
- name: SCYLLA_KEYSPACE
  value: file_service
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
- name: RUSTFS_ENDPOINT
  value: http://{{ $host }}:9006
- name: RUSTFS_ACCESS_KEY
  value: rustfsadmin
- name: RUSTFS_SECRET_KEY
  value: rustfsadmin
- name: RUSTFS_REGION
  value: us-east-1
- name: RUSTFS_BUCKET
  value: ofm-files
- name: RUSTFS_SECURE
  value: "false"
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9504"
- name: METRICS_PORT
  value: "9604"
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
