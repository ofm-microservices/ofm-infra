{{- define "ofm.serviceEnv.search-service" -}}
{{- $host := include "ofm.externalHost" . -}}
- name: APP_NAME
  value: search-service
- name: APP_ENV
  value: local
- name: LOG_LEVEL
  value: info
- name: ELASTICSEARCH_URL
  value: http://{{ $host }}:9200
- name: ELASTICSEARCH_INDEX
  value: gigs
- name: NATS_URL
  value: nats://{{ include "ofm.natsHost" . }}:4222
- name: NATS_USER
  value: ""
- name: NATS_PASSWORD
  value: ""
- name: NATS_SUBJECT_GIG_PUBLISHED
  value: gig.published
- name: NATS_SUBJECT_GIG_DELETED
  value: gig.deleted
- name: NATS_SUBJECT_SEARCH_GIG_INDEXED
  value: search.gig.indexed
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9511"
- name: METRICS_PORT
  value: "9612"
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
