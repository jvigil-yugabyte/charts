{{/* vim: set filetype=mustache: */}}

{{/* Expand the name of the chart. */}}
{{- define "yugabyte.name" -}}
  {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Generate a default fully qualified app name.
     We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
     If release name contains chart name it will be used as a full name. */}}
{{- define "yugabyte.fullname" -}}
  {{- if .Values.fullnameOverride -}}
    {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
  {{- else -}}
    {{- $name := default .Chart.Name .Values.nameOverride -}}
    {{- if contains $name .Release.Name -}}
      {{- .Release.Name | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
      {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Derive the memory hard limit for each pod based on the memory limit.
     Since the memory is represented in <x>GBi, we use this function to convert that into bytes.
     Multiplied by 870 since 0.85 * 1024 ~ 870 (floating calculations not supported) */}}
{{- define "yugabyte.memory_hard_limit" -}}
  {{- printf "%d" .limits.memory | regexFind "\\d+" | mul 1024 | mul 1024 | mul 870 -}}
{{- end -}}

{{/* Generate chart name and version as used by the chart label. */}}
{{- define "yugabyte.chart" -}}
  {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Generate list of data directories. */}}
{{- define "yugabyte.fs_data_dirs" -}}
  {{- if .Values.storage.ephemeral -}}
    /var/yugabyte
  {{- else -}}
    {{- range $index := until (int (.Storage.count)) -}}
      {{- if ne $index 0 }},{{ end -}}
      /mnt/disk{{ $index }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Generate server FQDN. */}}
{{- define "yugabyte.server_fqdn" -}}
  {{- printf "$(HOSTNAME).%s.$(NAMESPACE).svc.%s" .Service.name .Values.domainName -}}
{{- end -}}

{{/* Generate server broadcast address. */}}
{{- define "yugabyte.server_broadcast_address" -}}
  {{- include "yugabyte.server_fqdn" . }}:{{ index .Service.ports "tcp-rpc-port" -}}
{{- end -}}

{{/* Generate server RPC bind address. */}}
{{- define "yugabyte.rpc_bind_address" -}}
  {{- if .Values.istioCompatibility.enabled -}}
    0.0.0.0:{{ index .Service.ports "tcp-rpc-port" -}}
  {{- else -}}
    {{- include "yugabyte.server_fqdn" . -}}
  {{- end -}}
{{- end -}}

{{/* Generate server CQL proxy bind address. */}}
{{- define "yugabyte.cql_proxy_bind_address" -}}
  {{- if .Values.istioCompatibility.enabled -}}
    0.0.0.0:{{ index .Service.ports "tcp-yql-port" -}}
  {{- else -}}
    {{- include "yugabyte.server_fqdn" . -}}
  {{- end -}}
{{- end -}}

{{/* Generate server PGSQL proxy bind address. */}}
{{- define "yugabyte.pgsql_proxy_bind_address" -}}
  {{- eq .Values.ip_version_support "v6_only" | ternary "[::]" "0.0.0.0" -}}:{{ index .Service.ports "tcp-ysql-port" -}}
{{- end -}}

{{/* Generate server web interface. */}}
{{- define "yugabyte.webserver_interface" -}}
  {{- eq .Values.ip_version_support "v6_only" | ternary "[::]" "0.0.0.0" -}}
{{- end -}}

{{/* Generate comma-separated list of master addresses. */}}
{{- define "yugabyte.master_addresses" -}}
  {{- if .Values.isMultiAz -}}
    {{- .Values.masterAddresses -}}
  {{- else -}}
    {{- $master_replicas := .Values.replicas.master | int -}}
    {{- $cluster_domain_name := .Values.domainName -}}
    {{- $domain_name := (printf "yb-masters.$(NAMESPACE).svc.%s" $cluster_domain_name) -}}
    {{- range .Values.Services -}}
      {{- if eq .name "yb-masters" -}}
        {{- $port := (index .ports "tcp-rpc-port") -}}
        {{- range $index := until $master_replicas -}}
          {{- if ne $index 0 }},{{ end -}}
          yb-master-{{ $index }}.{{ $domain_name }}:{{ $port -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Generate replication factor. */}}
{{- define "yugabyte.replication_factor" -}}
  {{- if .Values.isMultiAz -}}
    {{- .Values.replicas.totalMasters -}}
  {{- else -}}
    {{- .Values.replicas.master -}}
  {{- end -}}
{{- end -}}

{{/* Generate enable YSQL boolean. */}}
{{- define "yugabyte.enable_ysql" -}}
  {{- if .Values.disableYsql }}false{{ else }}true{{ end -}}
{{- end -}}

{{/* Compute maximum number of unavailable pods based on the number of master replicas. */}}
{{- define "yugabyte.max_unavailable_for_quorum" -}}
  {{- $master_replicas_10x := .Values.replicas.master | int | mul 100 -}}
  {{- $max_unavailable_replicas := 100 | div (100 | sub (2 | div ($master_replicas_10x | add 100))) -}}
  {{- printf "%d" $max_unavailable_replicas -}}
{{- end -}}
