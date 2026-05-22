{{- define "ofm.serviceEnv.mail-service" -}}
{{- $host := include "ofm.externalHost" . -}}
{{- $secrets := default dict .Values._secrets -}}
{{- $mailSecrets := default dict $secrets.mail -}}
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: NATS_URL
  value: nats://{{ include "ofm.natsHost" . }}:4222
- name: SMTP_HOST
  value: smtp.gmail.com
- name: SMTP_PORT
  value: "587"
- name: SMTP_MODE
  value: starttls
- name: EMAIL_PASSWORD
  value: {{ default "" $mailSecrets.smtpPassword }}
- name: SENDER_EMAIL
  value: {{ default "" $mailSecrets.senderEmail }}
- name: SMTP_FROM_NAME
  value: OFM
- name: MAIL_TEMPLATE_DIR
  value: templates
- name: NATS_USER
  value: ""
- name: NATS_PASSWORD
  value: ""
- name: NATS_STREAM_MAIL_COMMANDS
  value: MAIL_COMMANDS
- name: NATS_STREAM_MAIL_EVENTS
  value: MAIL_EVENTS
- name: NATS_SUBJECT_MAIL_SEND
  value: mail.send
- name: NATS_SUBJECT_MAIL_SEND_RESULT
  value: mail.send.result
- name: NATS_DURABLE_MAIL_SEND
  value: mail_service_send
- name: NATS_MAIL_BATCH_SIZE
  value: "32"
- name: NATS_MAIL_MAX_WAIT
  value: 10ms
- name: NATS_MAIL_WORKERS
  value: "8"
- name: NATS_MAIL_QUEUE_SIZE
  value: "500"
- name: NATS_MAIL_ACK_WAIT
  value: 30s
- name: NATS_MAIL_MAX_DELIVER
  value: "5"
- name: NATS_MAIL_ADAPTIVE_ENABLED
  value: "false"
- name: NATS_MAIL_ADAPTIVE_CHECK_INTERVAL
  value: 2s
- name: NATS_MAIL_ADAPTIVE_MEDIUM_PENDING
  value: "200"
- name: NATS_MAIL_ADAPTIVE_HIGH_PENDING
  value: "1000"
- name: NATS_MAIL_ADAPTIVE_LOW_BATCH_SIZE
  value: "8"
- name: NATS_MAIL_ADAPTIVE_LOW_MAX_WAIT
  value: 25ms
- name: NATS_MAIL_ADAPTIVE_MEDIUM_BATCH_SIZE
  value: "32"
- name: NATS_MAIL_ADAPTIVE_MEDIUM_MAX_WAIT
  value: 10ms
- name: NATS_MAIL_ADAPTIVE_HIGH_BATCH_SIZE
  value: "128"
- name: NATS_MAIL_ADAPTIVE_HIGH_MAX_WAIT
  value: 2ms
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
