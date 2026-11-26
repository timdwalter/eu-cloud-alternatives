{{- define "textlib.authHost" -}}{{ .Values.authSubdomain }}.{{ .Values.domain }}{{- end -}}
{{- define "textlib.issuer" -}}https://{{ include "textlib.authHost" . }}/realms/{{ .Values.realm }}{{- end -}}
{{- define "textlib.internalIssuer" -}}http://keycloak:8080/realms/{{ .Values.realm }}{{- end -}}
{{- define "textlib.image" -}}
{{- $root := index . 0 -}}{{- $name := index . 1 -}}
{{- if $root.Values.images.registry -}}{{ $root.Values.images.registry }}/{{ end -}}{{ $name }}:{{ $root.Values.images.tag }}
{{- end -}}
