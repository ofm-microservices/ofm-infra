{{- define "ofm.serviceEnv.order-saga-service" -}}
{{- $host := include "ofm.externalHost" . -}}
- name: NAME
  value: order-saga-service
- name: ENV
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
  value: "9044"
- name: SCYLLA_USERNAME
  value: admin
- name: SCYLLA_PASSWORD
  value: admin
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
