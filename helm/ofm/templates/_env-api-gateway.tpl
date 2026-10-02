{{- define "ofm.serviceEnv.api-gateway" -}}
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
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
- name: USER_SERVICE_ADDRESS
  value: user-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9502
- name: CHAT_SERVICE_ADDRESS
  value: chat-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9512
- name: PAYMENT_SERVICE_ADDRESS
  value: payment-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9506
- name: ORDER_SERVICE_ADDRESS
  value: order-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9505
- name: ORDER_SAGA_ADDRESS
  value: order-saga-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9507
- name: REVIEW_SERVICE_ADDRESS
  value: review-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9510
- name: SEARCH_SERVICE_ADDRESS
  value: search-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9511
- name: HTTP_HOST
  value: 0.0.0.0
- name: HTTP_PORT
  value: "8080"
- name: FAULT_INJECTION_ENABLED
  value: "true"
- name: FAULT_INJECTION_PROFILE
  value: none
- name: FAULT_INJECTION_TARGET
  value: "*"
- name: FAULT_INJECTION_RATE
  value: "0"
- name: FAULT_INJECTION_DELAY
  value: 0s
- name: FAULT_INJECTION_MAX_FAILURES
  value: "0"
- name: FAULT_INJECTION_TTL
  value: 0s
- name: FAULT_INJECTION_TEST_TOKEN
  value: ofm-test-fault-token
- name: WS_PATH
  value: /ws
- name: JWT_ACCESS_SECRET
  value: {{ required "global.jwt.accessSecret is required" .Values.global.jwt.accessSecret | quote }}
- name: MIGRATION_SEARCH_MODE
  value: service
- name: MIGRATION_REDIS_HOST
  value: host.k3d.internal
- name: MIGRATION_REDIS_PORT
  value: "6387"
- name: MONOLITH_BASE_URL
  value: http://monolith.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:8000
- name: MONOLITH_HTTP_TIMEOUT
  value: 15s
- name: MONOLITH_RATE_LIMIT_BYPASS_TOKEN
  valueFrom:
    secretKeyRef:
      name: ofm-monolith-rate-limit
      key: token
      optional: true
- name: MIGRATION_WRITE_FALLBACK
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
