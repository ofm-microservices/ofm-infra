{{- define "ofm.serviceEnv.realtime-service" -}}
- name: APP_ENV
  value: local
- name: NATS_URL
  value: nats://{{ include "ofm.natsHost" . }}:4222
- name: JWT_ACCESS_SECRET
  value: aa96fae1a6eee39b879dad6b6bb372e63278257bf9f94010bc7d25693f61e38c
- name: HTTP_HOST
  value: 0.0.0.0
- name: HTTP_PORT
  value: "8082"
- name: METRICS_PORT
  value: "9610"
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
