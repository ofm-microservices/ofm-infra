{{- define "ofm.serviceEnv.monolith" -}}
{{- $host := include "ofm.externalHost" . -}}
- name: APP_ENV
  value: k3d
- name: LOG_LEVEL
  value: info
- name: HTTP_HOST
  value: 0.0.0.0
- name: HTTP_PORT
  value: "8000"
- name: METRICS_ENABLED
  value: "true"
- name: METRICS_HOST
  value: 0.0.0.0
- name: METRICS_PORT
  value: "9600"
- name: DB_HOST
  value: {{ $host }}
- name: DB_PORT
  value: "5433"
- name: DB_USER
  value: admin
- name: DB_PASSWORD
  value: admin
- name: DB_NAME
  value: ofm_monolith
- name: DB_SSL_MODE
  value: disable
- name: SERVICE_FEE
  value: "0.05"
- name: JWT_SECRET
  value: aa96fae1a6eee39b879dad6b6bb372e63278257bf9f94010bc7d25693f61e38c
- name: ACCESS_TOKEN_EXPIRATION
  value: "15"
- name: REFRESH_TOKEN_EXPIRATION
  value: "43200"
- name: MAX_CONNECTIONS
  value: "200"
- name: MONOLITH_RATE_LIMIT_BYPASS_TOKEN
  valueFrom:
    secretKeyRef:
      name: ofm-monolith-rate-limit
      key: token
      optional: true
- name: MAX_SEARCH_RESULTS
  value: "50"
- name: MAX_FREELANCE_BY_ID_REVIEWS
  value: "5"
- name: MAX_USER_BY_ID_REVIEWS
  value: "5"
- name: MAX_USER_BY_ID_SERVICES
  value: "8"
- name: MAX_MY_PROFILE_ORDER_RESULTS
  value: "15"
- name: MAX_MY_PROFILE_SERVICE_RESULTS
  value: "15"
- name: MAX_MY_PROFILE_REQUEST_RESULTS
  value: "15"
- name: RSA_PRIVATE_KEY_PATH
  value: /app/keys/private.pem
- name: RSA_PUBLIC_KEY_PATH
  value: /app/keys/public.pem
- name: MIGRATION_KAFKA_BROKERS
  value: {{ include "ofm.kafkaHost" . }}:9092
- name: MIGRATION_KAFKA_CONSUMER_GROUP
  value: monolith-projection
- name: MIGRATION_KAFKA_DLQ_TOPIC
  value: migration.dead-letter
- name: MIGRATION_RECOVERY_COMMAND_TOPIC
  value: migration.recovery.commands
- name: MIGRATION_PROJECTION_MODE
  value: mapping-only
- name: MIGRATION_FALLBACK_SKIP_EXTERNAL_SIDE_EFFECTS
  value: "true"
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
