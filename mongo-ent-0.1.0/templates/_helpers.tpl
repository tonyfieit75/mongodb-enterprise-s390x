{{- define "mongo-ent.name" -}}
mongo-ent
{{- end -}}

{{- define "mongo-ent.fullname" -}}
{{ include "mongo-ent.name" . }}
{{- end -}}
