{{/*
Expand the name of the chart.
*/}}
{{- define "nautobot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "nautobot.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nautobot.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nautobot.labels" -}}
helm.sh/chart: {{ include "nautobot.chart" . }}
{{ include "nautobot.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nautobot.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nautobot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "nautobot.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "nautobot.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Environment variables for Nautobot
*/}}
{{- define "nautobot.env" -}}
- name: NAUTOBOT_DB_NAME
  value: {{ .Values.database.name | quote }}
- name: NAUTOBOT_DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.database.existingSecret }}
      key: {{ .Values.database.usernameKey }}
- name: NAUTOBOT_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.database.existingSecret }}
      key: {{ .Values.database.passwordKey }}
- name: NAUTOBOT_DB_HOST
  value: {{ .Values.database.host | quote }}
- name: NAUTOBOT_DB_PORT
  value: {{ .Values.database.port | quote }}
- name: NAUTOBOT_REDIS_HOST
  value: {{ .Values.redis.host | quote }}
- name: NAUTOBOT_REDIS_PORT
  value: {{ .Values.redis.port | quote }}
- name: NAUTOBOT_REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.redis.existingSecret }}
      key: {{ .Values.redis.passwordKey }}
- name: NAUTOBOT_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.nautobot.secretKeySecret }}
      key: secret-key
- name: NAUTOBOT_SUPERUSER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.nautobot.superuser.passwordSecret }}
      key: {{ .Values.nautobot.superuser.passwordKey }}
- name: NAUTOBOT_CREATE_SUPERUSER
  value: "true"
- name: NAUTOBOT_SUPERUSER_NAME
  value: {{ .Values.nautobot.superuser.username | quote }}
- name: NAUTOBOT_SUPERUSER_EMAIL
  value: {{ .Values.nautobot.superuser.email | quote }}
{{ end }}
