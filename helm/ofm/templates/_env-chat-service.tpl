{{- define "ofm.serviceEnv.chat-service" -}}
{{- $host := include "ofm.externalHost" . -}}
{{- $service := index .Values.services "chat-service" | default dict -}}
- name: APP_NAME
  value: chat-service
- name: APP_ENV
  value: local
- name: APP_LOG_LEVEL
  value: info
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9512"
- name: SCYLLA_HOSTS
  value: {{ $host }}
- name: SCYLLA_PORT
  value: {{ quote (toString ($service.scyllaPort | default 9045)) }}
- name: SCYLLA_KEYSPACE
  value: chat_service
- name: SCYLLA_USERNAME
  value: admin
- name: SCYLLA_PASSWORD
  value: admin
- name: CURSOR_SECRET
  value: 4b0970e1c2d84722a07a3d05df6017f7c6d1b424f8ce3a2ef3a4283d1d26f8d8
- name: CRYPTO_SECRET
  value: 2a59d60bc59eeb3474eb0beeb1656d1c6b1745d522857e86f6e8a83f44b8800d
- name: FILE_SERVICE_ADDRESS
  value: file-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9504
- name: NATS_URL
  value: nats://{{ include "ofm.natsHost" . }}:4222
- name: NATS_USER
  value: ""
- name: NATS_PASSWORD
  value: ""
- name: NATS_STREAM_CHAT_LIFECYCLE
  value: CHAT_LIFECYCLE
- name: NATS_STREAM_REALTIME
  value: REALTIME
- name: NATS_SUBJECT_CHAT_CREATE
  value: chat.create
- name: NATS_SUBJECT_CHAT_CLOSE
  value: chat.close
- name: NATS_SUBJECT_REALTIME
  value: realtime
- name: METRICS_ENABLED
  value: "true"
- name: METRICS_HOST
  value: 0.0.0.0
- name: METRICS_PORT
  value: "9613"
- name: METRICS_PATH
  value: /metrics
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
