{{- define "ofm.serviceEnv.mail-service" -}}
{{- $host := include "ofm.externalHost" . -}}
{{- $secrets := default dict .Values._secrets -}}
{{- $mailSecrets := default dict $secrets.mail -}}
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: KAFKA_BROKERS
  value: {{ include "ofm.kafkaHost" . }}:9092
- name: REDIS_HOST
  value: {{ $host }}
- name: REDIS_PORT
  value: "6385"
- name: REDIS_DB
  value: "0"
- name: KAFKA_MAIL_GROUP_ID
  value: mail-service
- name: SMTP_HOST
  value: smtp.gmail.com
- name: SMTP_PORT
  value: "587"
- name: SMTP_MODE
  value: fake
- name: EMAIL_PASSWORD
  value: {{ default "" $mailSecrets.smtpPassword }}
- name: SENDER_EMAIL
  value: {{ default "" $mailSecrets.senderEmail }}
- name: SMTP_FROM_NAME
  value: OFM
- name: MAIL_TEMPLATE_DIR
  value: templates
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
