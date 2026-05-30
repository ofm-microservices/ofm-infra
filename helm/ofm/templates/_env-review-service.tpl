{{- define "ofm.serviceEnv.review-service" -}}
{{- $host := include "ofm.externalHost" . -}}
{{- $secrets := default dict .Values._secrets -}}
{{- $reviewSecrets := default dict $secrets.review -}}
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: DB_HOST
  value: {{ $host }}
- name: DB_PORT
  value: "5438"
- name: DB_USER
  value: admin
- name: DB_PASSWORD
  value: admin
- name: DB_NAME
  value: review_service
- name: REDIS_HOST
  value: {{ $host }}
- name: REDIS_PORT
  value: "6383"
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
- name: NATS_STREAM_REVIEW_EVENTS
  value: REVIEW_EVENTS
- name: NATS_SUBJECT_REVIEW_GIG_PROJECTION_REQUESTED
  value: review.projection.gig
- name: NATS_SUBJECT_REVIEW_USER_PROJECTION_REQUESTED
  value: review.projection.user
- name: NATS_SUBJECT_REVIEW_GIG_RATING_REQUESTED
  value: review.rating.gig
- name: NATS_SUBJECT_REVIEW_SELLER_RATING_REQUESTED
  value: review.rating.seller
- name: NATS_SUBJECT_REVIEW_AUTHOR_RETRY_REQUESTED
  value: review.author.retry.requested
- name: NATS_SUBJECT_REVIEW_AVATAR_RETRY_REQUESTED
  value: review.avatar.retry.requested
- name: NATS_DURABLE_REVIEW_GIG_RATING
  value: review_service_gig_rating
- name: NATS_DURABLE_REVIEW_SELLER_RATING
  value: review_service_seller_rating
- name: NATS_STREAM_SAGA_COMMANDS
  value: SAGA_REVIEW_COMMANDS
- name: REVIEW_PAGE_SIZE
  value: 10
- name: REVIEW_WINDOW_SIZE
  value: 100
- name: REVIEW_WINDOW_TTL
  value: 1m
- name: REVIEW_CURSOR_SECRET
  value: {{ default "" $reviewSecrets.cursorSecret }}
- name: ORDER_SERVICE_ADDRESS
  value: order-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9505
- name: USER_SERVICE_ADDRESS
  value: user-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9502
- name: FILE_SERVICE_ADDRESS
  value: file-service.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:9504
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9510"
- name: METRICS_PORT
  value: "9611"
- name: TRACING_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: http://otel-collector.{{ .Release.Namespace }}.svc.{{ .Values.global.clusterDomain }}:4318
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: http/protobuf
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
