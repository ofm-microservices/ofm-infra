{{- define "ofm.serviceEnv.file-service" -}}
{{- $host := include "ofm.externalHost" . -}}
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: DB_HOST
  value: {{ $host }}
- name: DB_PORT
  value: "5440"
- name: DB_USER
  value: admin
- name: DB_PASSWORD
  value: admin
- name: NATS_USER
  value: ""
- name: NATS_PASSWORD
  value: ""
- name: DB_NAME
  value: file_service
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
- name: KAFKA_BROKERS
  value: {{ include "ofm.kafkaHost" . }}:9092
- name: KAFKA_FILE_RECOVERY_TOPIC
  value: migration.recovery.commands.file
- name: KAFKA_FILE_RECOVERY_GROUP
  value: file-service-recovery
- name: KAFKA_FILE_RECOVERY_COMPLETED_TOPIC
  value: migration.recovery.completed
- name: KAFKA_FILE_DLQ_TOPIC
  value: file-service-dead-letter
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
