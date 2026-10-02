{{- define "ofm.serviceEnv.realtime-service" -}}
- name: APP_ENV
  value: local
- name: KAFKA_BROKERS
  value: {{ include "ofm.kafkaHost" . }}:9092
- name: KAFKA_REALTIME_GROUP_ID
  value: realtime-service
- name: KAFKA_CHAT_EVENTS_TOPIC
  value: migration.chat-service.chat.changed
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: REDIS_HOST
  value: {{ include "ofm.externalHost" . }}
- name: REDIS_PORT
  value: "6386"
- name: REDIS_DB
  value: "0"
- name: REDIS_POOL_SIZE
  value: "150"
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
