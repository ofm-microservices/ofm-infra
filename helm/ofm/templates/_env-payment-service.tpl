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
- name: KAFKA_BROKERS
  value: {{ include "ofm.kafkaHost" . }}:9092
- name: KAFKA_PAYMENT_GROUP_ID
  value: payment-service
- name: KAFKA_PAYMENT_INTENT_TOPIC
  value: payment.intent
- name: KAFKA_PAYMENT_PROJECTION_TOPIC
  value: payment.projection
- name: STRIPE_SECRET_KEY
  value: {{ default "" $paymentSecrets.stripeSecretKey }}
- name: STRIPE_FAKE_ENABLED
  value: {{ default false $stripe.fakeEnabled | quote }}
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
- name: STRIPE_SKIP_TRANSFERS
  value: "true"
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
