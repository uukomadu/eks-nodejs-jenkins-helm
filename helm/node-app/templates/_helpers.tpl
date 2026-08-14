{{- define "node-app.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "node-app.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "node-app.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "node-app.labels" -}}
app.kubernetes.io/name: {{ include "node-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end }}

{{- define "node-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "node-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
