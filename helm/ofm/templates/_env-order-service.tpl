{{- define "ofm.serviceEnv.order-service" -}}
{{- $host := include "ofm.externalHost" . -}}
- name: APP_ENV
  value: local
- name: APP_LOG_LEVEL
  value: info
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9505"
- name: DB_HOST
  value: {{ $host }}
- name: DB_PORT
  value: "5437"
- name: DB_USER
  value: admin
- name: DB_PASSWORD
  value: admin
- name: DB_NAME
  value: order_service
- name: REDIS_HOST
  value: {{ $host }}
- name: REDIS_PORT
  value: "6382"
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
- name: NATS_STREAM_ORDER_EVENTS
  value: ORDER_EVENTS
- name: NATS_STREAM_ORDER_COMMANDS
  value: ORDER_COMMANDS
- name: NATS_SUBJECT_ORDER_CREATED
  value: order.created
- name: NATS_SUBJECT_ORDER_PAYMENT_PENDING
  value: order.payment_pending
- name: NATS_SUBJECT_ORDER_FUNDED
  value: order.funded
- name: NATS_SUBJECT_ORDER_FAILED
  value: order.failed
- name: NATS_SUBJECT_ORDER_REQUIREMENTS_SUBMITTED
  value: order.requirements_submitted
- name: NATS_SUBJECT_ORDER_MESSAGE_SUBMITTED
  value: order.message_submitted
- name: NATS_SUBJECT_ORDER_ATTACHMENT_UPLOADED
  value: order.attachment_uploaded
- name: METRICS_PORT
  value: "9608"
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
