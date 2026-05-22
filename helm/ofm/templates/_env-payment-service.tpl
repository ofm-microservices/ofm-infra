{{- define "ofm.serviceEnv.payment-service" -}}
{{- $host := include "ofm.externalHost" . -}}
{{- $paymentSvc := index .Values.services "payment-service" -}}
{{- $stripe := default dict $paymentSvc.stripe -}}
{{- $secrets := default dict .Values._secrets -}}
{{- $paymentSecrets := default dict $secrets.payment -}}
- name: APP_ENV
  value: local
- name: APP_LOG_LEVEL
  value: info
- name: HTTP_HOST
  value: 0.0.0.0
- name: HTTP_PORT
  value: "8081"
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9506"
- name: DB_HOST
  value: {{ $host }}
- name: DB_PORT
  value: "5436"
- name: DB_USER
  value: admin
- name: DB_PASSWORD
  value: admin
- name: DB_NAME
  value: payment_service
- name: REDIS_HOST
  value: {{ $host }}
- name: REDIS_PORT
  value: "6381"
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
- name: NATS_STREAM_PAYMENT_COMMANDS
  value: PAYMENT_COMMANDS
- name: NATS_STREAM_PAYMENT_EVENTS
  value: PAYMENT_EVENTS
- name: NATS_SUBJECT_PAYMENT_INTENT
  value: payment.intent
- name: NATS_SUBJECT_PAYMENT_INTENT_RESULT
  value: payment.intent.result
- name: NATS_SUBJECT_PAYMENT_WEBHOOK
  value: payment.webhook
- name: NATS_SUBJECT_PAYMENT_STATUS
  value: payment.status
- name: NATS_SUBJECT_PAYMENT_COMPLETED
  value: payment.completed
- name: NATS_SUBJECT_PAYMENT_FAILED
  value: payment.failed
- name: NATS_SUBJECT_PAYMENT_COMPENSATION
  value: payment.compensation
- name: NATS_COMMAND_BATCH_SIZE
  value: "32"
- name: NATS_COMMAND_MAX_WAIT
  value: 10ms
- name: STRIPE_SECRET_KEY
  value: {{ default "" $paymentSecrets.stripeSecretKey }}
- name: STRIPE_PAYMENT_WEBHOOK_SECRET
  value: {{ default "" $paymentSecrets.checkoutWebhookSecret }}
- name: STRIPE_FREELANCER_ONBOARDING_WEBHOOK_SECRET
  value: {{ default "" $paymentSecrets.connectWebhookSecret }}
- name: STRIPE_CONNECT_RETURN_URL
  value: {{ default "http://api.ofm.local/v1/freelancer/onboarding/return" $stripe.connectReturnURL }}
- name: STRIPE_CONNECT_REFRESH_URL
  value: {{ default "http://api.ofm.local/v1/freelancer/onboarding/refresh" $stripe.connectRefreshURL }}
- name: STRIPE_CONNECT_COUNTRY
  value: {{ default "US" $stripe.connectCountry }}
- name: METRICS_PORT
  value: "9609"
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
