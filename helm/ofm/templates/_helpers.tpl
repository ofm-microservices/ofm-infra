{{- define "ofm.fullname" -}}
{{- printf "%s" .Release.Name -}}
{{- end -}}

{{- define "ofm.serviceDNS" -}}
{{- printf "%s.%s.svc.%s" .serviceName .Release.Namespace .Values.global.clusterDomain -}}
{{- end -}}

{{- define "ofm.externalHost" -}}
{{- required "global.externalHost must be set" .Values.global.externalHost -}}
{{- end -}}

{{- define "ofm.natsHost" -}}
{{- default (include "ofm.externalHost" .) .Values.global.natsHost -}}
{{- end -}}

{{- define "ofm.labels" -}}
app.kubernetes.io/name: ofm
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{- define "ofm.serviceEnv" -}}
{{- include (printf "ofm.serviceEnv.%s" .serviceName) . -}}
{{- end -}}
