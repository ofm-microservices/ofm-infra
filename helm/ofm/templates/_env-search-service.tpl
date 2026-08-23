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
- name: KAFKA_BROKERS
  value: {{ include "ofm.kafkaHost" . }}:9092
- name: KAFKA_GIG_EVENTS_TOPIC
  value: migration.gig-service.gigs.changed
- name: KAFKA_SEARCH_GROUP_ID
  value: search-service
- name: GRPC_HOST
  value: 0.0.0.0
- name: GRPC_PORT
  value: "9511"
- name: METRICS_PORT
  value: "9612"
- name: SERVICE_VERSION
  value: k3s
{{- end -}}
