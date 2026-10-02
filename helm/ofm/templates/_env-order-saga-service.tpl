{{- define "ofm.serviceEnv.order-saga-service" -}}
{{- $host := include "ofm.externalHost" . -}}
- name: NAME
  value: order-saga-service
- name: ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: KAFKA_BROKERS
  value: {{ include "ofm.kafkaHost" . }}:9092
- name: KAFKA_ORDER_SAGA_GROUP_ID
  value: order-saga-service
- name: ORDER_SAGA_RECOVERY_TOPIC
  value: migration.recovery.commands.order_saga
- name: ORDER_SAGA_RECOVERY_GROUP
  value: order-saga-service-recovery
- name: ORDER_SAGA_RECOVERY_COMPLETED_TOPIC
  value: migration.recovery.completed
- name: NATS_USER
  value: ""
- name: NATS_PASSWORD
  value: ""
- name: SUBJECT_ORDER_FUNDED
  value: order.funded
- name: DB_HOST
  value: {{ $host }}
- name: DB_PORT
  value: "5441"
- name: DB_USER
  value: admin
- name: DB_PASSWORD
  value: admin
- name: DB_NAME
  value: order_saga
- name: GIG_SERVICE_ADDRESS
  value: gig-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9503
- name: ORDER_SERVICE_ADDRESS
  value: order-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9505
- name: PAYMENT_SERVICE_ADDRESS
  value: payment-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9506
- name: FILE_SERVICE_ADDRESS
  value: file-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9504
- name: AUTH_SERVICE_ADDRESS
  value: auth-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9501
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9507"
- name: METRICS_PORT
  value: "9607"
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
