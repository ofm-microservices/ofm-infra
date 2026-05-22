{{- define "ofm.serviceEnv.api-gateway" -}}
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
- name: REGISTRATION_SAGA_ADDRESS
  value: registration-saga-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9500
- name: AUTH_SERVICE_ADDRESS
  value: auth-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9501
- name: GIG_SERVICE_ADDRESS
  value: gig-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9503
- name: PAYMENT_SERVICE_ADDRESS
  value: payment-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9506
- name: ORDER_SAGA_ADDRESS
  value: order-saga-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9507
- name: HTTP_HOST
  value: 0.0.0.0
- name: HTTP_PORT
  value: "8080"
- name: WS_PATH
  value: /ws
- name: JWT_ACCESS_SECRET
  value: aa96fae1a6eee39b879dad6b6bb372e63278257bf9f94010bc7d25693f61e38c
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
