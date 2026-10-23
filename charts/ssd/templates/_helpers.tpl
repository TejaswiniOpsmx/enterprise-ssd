{{/*
{{- define "imagePullSecret" }}
{{- with .Values.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .repoUrl .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}
*/}}

{{/*
Common labels for metadata.
*/}}
{{- define "ssd.standard-labels" -}}
heritage: {{ .Release.Service | quote }}
release: {{ .Release.Name | quote }}
chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
{{- if .Values.customLabels }}
{{ toYaml .Values.customLabels }}
{{- end }}
{{- end -}}

{{/*
Return the proper UI image name
*/}}
{{- define "ui.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.ui.image.repository -}}
{{- $tag := .Values.ui.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper SSD-DB image name
*/}}
{{- define "db.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.db.image.repository -}}
{{- $tag := .Values.db.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper Tool Chain Image
*/}}
{{- define "toolchain.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.toolchain.image.repository -}}
{{- $tag := .Values.toolchain.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper Supplychain-api Image
*/}}
{{- define "supplychainapi.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.supplychainapi.image.repository -}}
{{- $tag := .Values.supplychainapi.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
 Return the proper Supplychain-preprocessor Image
*/}}
 {{- define "supplychainpreprocessor.image" -}}
 {{- $registryName := .Values.imageCredentials.registry -}}
 {{- $repositoryName := .Values.supplychainpreprocessor.image.repository -}}
 {{- $tag := .Values.supplychainpreprocessor.image.tag | toString -}}
 {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
 {{- end -}}

{{/*
 Return the proper ssd-opa Image
*/}}
 {{- define "ssdopa.image" -}}
 {{- $registryName := .Values.imageCredentials.registry -}}
 {{- $repositoryName := .Values.ssdopa.image.repository -}}
 {{- $tag := .Values.ssdopa.image.tag | toString -}}
 {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
 {{- end -}}

{{/*
 Return the proper ssd-gate Image
*/}}
 {{- define "ssdgate.image" -}}
 {{- $registryName := .Values.imageCredentials.registry -}}
 {{- $repositoryName := .Values.ssdgate.image.repository -}}
 {{- $tag := .Values.ssdgate.image.tag | toString -}}
 {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
 {{- end -}}

{{/*
 Return the proper dgraph Image
*/}}
 {{- define "dgraph.image" -}}
 {{- $registryName := .Values.imageCredentials.registry -}}
 {{- $repositoryName := .Values.dgraph.image.repository -}}
 {{- $tag := .Values.dgraph.image.tag | toString -}}
 {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
 {{- end -}}

{{/*
 Return the proper ratel Image
*/}}
 {{- define "ratel.image" -}}
 {{- $registryName := .Values.imageCredentials.registry -}}
 {{- $repositoryName := .Values.ratel.image.repository -}}
 {{- $tag := .Values.ratel.image.tag | toString -}}
 {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
 {{- end -}}


{{/*
 Return the proper Token-Machine Image
*/}}
 {{- define "tokenmachine.image" -}}
 {{- $registryName := .Values.imageCredentials.registry -}}
 {{- $repositoryName := .Values.tokenmachine.image.repository -}}
 {{- $tag := .Values.tokenmachine.image.tag | toString -}}
 {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
 {{- end -}}

{{/*
 Return the proper Curl Image
*/}}
 {{- define "curl.image" -}}
 {{- $registryName := .Values.imageCredentials.registry -}}
 {{- $repositoryName := .Values.curl.image.repository -}}
 {{- $tag := .Values.curl.image.tag | toString -}}
 {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
 {{- end -}}

{{/*
Return the proper Mobsf image name
*/}}
{{- define "mobsf.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.mobsf.image.repository -}}
{{- $tag := .Values.mobsf.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper ZAP image name
*/}}
{{- define "zap.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.zap.image.repository -}}
{{- $tag := .Values.zap.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/* vim: set filetype=mustache: */}}
{{/*
Renders a value that contains template.
Usage:
{{ include "tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "tplvalues.render" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}


{{/*
Redis base URL for Spinnaker
*/}}
{{- define "ssd.redisBaseURL" -}}
{{- if .Values.installRedis }}
{{- printf "redis://:%s@%s-redis-master:6379" .Values.redis.password .Release.Name -}}
{{- else if .Values.redis.external.password }}
{{- printf "redis://:%s@%s:%s" .Values.redis.external.password .Values.redis.external.host (.Values.redis.external.port | toString) -}}
{{- else }}
{{- printf "redis://%s:%s" .Values.redis.external.host (.Values.redis.external.port | toString) -}}
{{- end }}
{{- end }}


{{/*
Return the proper OTEL image name
*/}}
{{- define "otel.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.otel.image.repository -}}
{{- $tag := .Values.otel.image.tag | toString -}}
{{- printf "%s:%s" $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper Snyk Monitor image name
*/}}
{{- define "snykmonitor.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.snykmonitor.image.repository -}}
{{- $tag := .Values.snykmonitor.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Adding the New container to all Services
*/}}
{{- define "otel.sidecar.container" }}
- name: otel-sidecar
  image: {{ template "otel.image" . }}
  args:
    - '--config=/etc/otel/otel-sidecar-config.yaml'
  resources: {}
  volumeMounts:
    - name: otel-sidecar-volume
      mountPath: /etc/otel
    - name: logs
      readOnly: true
      mountPath: /app/logs
  {{- if .Values.otel.securityContext }}
  securityContext:
  {{ toYaml .Values.otel.securityContext | nindent 12 }}
  {{- else }}
  securityContext: {{ default "{}" }}
  {{- end }}
  {{- with .Values.otel.resources }}
  resources:
  {{- toYaml . | nindent 12 }}
  {{- end }}
{{- end }}

{{/*
Return the proper Source Scan Image
*/}}
{{- define "sourcescan.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.sourcescan.image.repository -}}
{{- $tag := .Values.sourcescan.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
 Return the proper k8s-decoder Image
*/}}
 {{- define "k8sdecoder.image" -}}
 {{- $registryName := .Values.imageCredentials.registry -}}
 {{- $repositoryName := .Values.k8sdecoder.image.repository -}}
 {{- $tag := .Values.k8sdecoder.image.tag | toString -}}
 {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
 {{- end -}}

{{/*
Return the proper kubescape-service image name
*/}}
{{- define "kubescape.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.kubescape.image.repository -}}
{{- $tag := .Values.kubescape.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper opsmx-custom-binaries image name
*/}}
{{- define "opsmxcustombinaries.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.opsmxcustombinaries.image.repository -}}
{{- $tag := .Values.opsmxcustombinaries.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper kubernetes-detector image name
*/}}
{{- define "kubedetector.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.kubedetector.image.repository -}}
{{- $tag := .Values.kubedetector.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper Project Monitor Image
*/}}
{{- define "projectmonitor.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.projectmonitor.image.repository -}}
{{- $tag := .Values.projectmonitor.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper SSD Reschduler Image
*/}}
{{- define "ssdrescheduler.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.ssdrescheduler.image.repository -}}
{{- $tag := .Values.ssdrescheduler.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper Artifact Scan Image
*/}}
{{- define "artifactscan.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.artifactscan.image.repository -}}
{{- $tag := .Values.artifactscan.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}


{{/*
Return the proper S3 details
*/}}
{{- define "s3.bucketname" -}}
{{- $fullurl := .Values.s3bucketurl }}
{{- $value := regexSplit "\\.s3\\." $fullurl -1 }}
{{- $protocol := index $value 0 }}
{{- $https := regexSplit "//" $protocol -1 }}
{{- $bucketname := index $https 1 }}
{{- printf "%s" $bucketname -}}
{{- end }}

{{- define "s3.protocolcheck" -}}
{{- $fullurl := .Values.s3bucketurl }}
{{- $parts := regexSplit "://" $fullurl -1 }}
{{- $scheme := index $parts 0 }}
{{- if eq $scheme "https" -}}
"true"
{{- else -}}
"false"
{{- end }}
{{- end }}


{{/*
Return the proper InitContainer Images
*/}}
{{- define "initcontainer.images" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.initContainer.image.repository -}}
{{- $tag := .Values.initContainer.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}


{{/*
Return the proper Rabbitmq Images
*/}}
{{- define "rabbitmq.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.rabbitmq.image.repository -}}
{{- $tag := .Values.rabbitmq.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper Rabbitmq Images
*/}}
{{- define "ssdauditservice.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.ssdauditservice.image.repository -}}
{{- $tag := .Values.ssdauditservice.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper License Generator Images
*/}}
{{- define "licensegenerator.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.licensegenerator.image.repository -}}
{{- $tag := .Values.licensegenerator.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper DLVS Images
*/}}
{{- define "dlvs.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.dlvs.image.repository -}}
{{- $tag := .Values.dlvs.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper Aishield Images
*/}}
{{- define "aishield.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.aishield.image.repository -}}
{{- $tag := .Values.aishield.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper SSD Notification Service Image
*/}}
{{- define "ssdnotificationservice.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.ssdnotificationservice.image.repository -}}
{{- $tag := .Values.ssdnotificationservice.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper AI Remediation Image
*/}}
{{- define "airemediation.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.airemediation.image.repository -}}
{{- $tag := .Values.airemediation.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper PRISM IAC Image
*/}}
{{- define "prismiac.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.prismiac.image.repository -}}
{{- $tag := .Values.prismiac.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper PENTESTGPT WRAPPER Image
*/}}
{{- define "pentestgpt.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.pentestgpt.image.repository -}}
{{- $tag := .Values.pentestgpt.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper CHECKMARX WRAPPER Image
*/}}
{{- define "checkmarx.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.checkmarx.image.repository -}}
{{- $tag := .Values.checkmarx.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper AIBOM WRAPPER Image
*/}}
{{- define "aibom.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.aibom.image.repository -}}
{{- $tag := .Values.aibom.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

{{/*
Return the proper OPSMX ASSISTANT Image
*/}}
{{- define "opsmxassistant.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.opsmxassistant.image.repository -}}
{{- $tag := .Values.opsmxassistant.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}

Return the proper MCP SERVER Image
*/}}
{{- define "mcpserver.image" -}}
{{- $registryName := .Values.imageCredentials.registry -}}
{{- $repositoryName := .Values.mcpserver.image.repository -}}
{{- $tag := .Values.mcpserver.image.tag | toString -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}
