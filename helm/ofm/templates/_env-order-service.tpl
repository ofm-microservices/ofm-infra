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
  value: "5436"
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
- name: KAFKA_BROKERS
  value: {{ include "ofm.kafkaHost" . }}:9092
- name: KAFKA_ORDER_GROUP_ID
  value: order-service
- name: KAFKA_ORDER_RECOVERY_TOPIC
  value: migration.recovery.commands.order
- name: KAFKA_ORDER_RECOVERY_GROUP
  value: order-service-recovery
- name: KAFKA_ORDER_RECOVERY_COMPLETED_TOPIC
  value: migration.recovery.completed
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
- name: NATS_SUBJECT_ORDER_FAILED
  value: order.failed
- name: NATS_SUBJECT_ORDER_REQUIREMENTS_SUBMITTED
  value: order.requirements_submitted
- name: NATS_SUBJECT_ORDER_MESSAGE_SUBMITTED
  value: order.message_submitted
- name: NATS_SUBJECT_ORDER_ATTACHMENT_UPLOADED
  value: order.attachment_uploaded
- name: NATS_SUBJECT_ORDER_FUNDED
  value: order.funded
- name: NATS_SUBJECT_ORDER_REQUIREMENTS_PROJECTION_REQUESTED
  value: order.projection.requirements
- name: NATS_DURABLE_ORDER_REQUIREMENTS_PROJECTION
  value: order_service_requirements_projection
- name: NATS_SUBJECT_ORDER_DELIVERY_PROJECTION_REQUESTED
  value: order.projection.delivery
- name: NATS_DURABLE_ORDER_DELIVERY_PROJECTION
  value: order_service_delivery_projection
- name: FILE_SERVICE_ADDRESS
  value: file-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9504
- name: USER_SERVICE_ADDRESS
  value: user-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9502
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
