{{- define "hydrosat-dagster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "hydrosat-dagster.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" (include "hydrosat-dagster.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "hydrosat-dagster.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "hydrosat-dagster.databaseSecretName" -}}
{{- if .Values.database.secretName -}}
{{- .Values.database.secretName -}}
{{- else -}}
{{- printf "%s-db" (include "hydrosat-dagster.fullname" .) -}}
{{- end -}}
{{- end -}}
