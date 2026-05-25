{{- define "ofm.serviceEnv.review-service" -}}
{{- $host := include "ofm.externalHost" . -}}
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: DB_HOST
  value: {{ $host }}
- name: DB_PORT
  value: "5438"
- name: DB_USER
  value: admin
- name: DB_PASSWORD
  value: admin
- name: DB_NAME
  value: review_service
- name: REDIS_HOST
  value: {{ $host }}
- name: REDIS_PORT
  value: "6383"
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
- name: ORDER_SERVICE_ADDRESS
  value: order-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9505
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9510"
- name: METRICS_PORT
  value: "9611"
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
