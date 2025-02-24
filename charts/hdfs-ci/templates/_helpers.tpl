{{/* vim: set filetype=mustache: */}}
{{/*
Create a short app name.
*/}}
{{- define "hdfs-ci.name" -}}
hdfs-ci
{{- end -}}

{{/*
Create a fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "hdfs-ci.fullname" -}}
{{- if .Values.global.fullnameOverride -}}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "hdfs-ci.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the subchart label.
*/}}
{{- define "hdfs-ci.subchart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "zookeeper-fullname" -}}
{{- $fullname := include "hdfs-ci.fullname" . -}}
{{- if contains "zookeeper" $fullname -}}
{{- printf "%s" $fullname -}}
{{- else -}}
{{- printf "%s-zookeeper" $fullname | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "hdfs-ci.config.name" -}}
{{- template "hdfs-ci.name" . -}}-config
{{- end -}}

{{- define "hdfs-ci.config.fullname" -}}
{{- $fullname := include "hdfs-ci.fullname" . -}}
{{- if contains "config" $fullname -}}
{{- printf "%s" $fullname -}}
{{- else -}}
{{- printf "%s-config" $fullname | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "hdfs-ci.krb5.name" -}}
{{- template "hdfs-ci.name" . -}}-krb5
{{- end -}}

{{- define "hdfs-ci.krb5.fullname" -}}
{{- $fullname := include "hdfs-ci.fullname" . -}}
{{- if contains "config" $fullname -}}
{{- printf "%s" $fullname -}}
{{- else -}}
{{- printf "%s-krb5" $fullname | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "hdfs-ci.journalnode.name" -}}
{{- template "hdfs-ci.name" . -}}-journalnode
{{- end -}}

{{- define "hdfs-ci.journalnode.fullname" -}}
{{- $fullname := include "hdfs-ci.fullname" . -}}
{{- if contains "journalnode" $fullname -}}
{{- printf "%s" $fullname -}}
{{- else -}}
{{- printf "%s-journalnode" $fullname | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "hdfs-ci.namenode.name" -}}
{{- template "hdfs-ci.name" . -}}-namenode
{{- end -}}

{{- define "hdfs-ci.namenode.fullname" -}}
{{- $fullname := include "hdfs-ci.fullname" . -}}
{{- if contains "namenode" $fullname -}}
{{- printf "%s" $fullname -}}
{{- else -}}
{{- printf "%s-namenode" $fullname | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "hdfs-ci.datanode.name" -}}
{{- template "hdfs-ci.name" . -}}-datanode
{{- end -}}

{{- define "hdfs-ci.datanode.fullname" -}}
{{- $fullname := include "hdfs-ci.fullname" . -}}
{{- if contains "datanode" $fullname -}}
{{- printf "%s" $fullname -}}
{{- else -}}
{{- printf "%s-datanode" $fullname | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create the kerberos principal suffix for core HDFS services
*/}}
{{- define "hdfs-principal" -}}
{{- printf "hdfs/_HOST@%s" .Values.global.kerberosRealm -}}
{{- end -}}

{{/*
Create the kerberos principal for HTTP services
*/}}
{{- define "http-principal" -}}
{{- printf "HTTP/_HOST@%s" .Values.global.kerberosRealm -}}
{{- end -}}

{{/*
Create the name for a Kubernetes Configmap containing a Kerberos config file.
*/}}
{{- define "krb5-configmap" -}}
{{- if .Values.global.kerberosConfigMapOverride -}}
{{- .Values.global.kerberosConfigMapOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "hdfs-ci.krb5.fullname" . -}}
{{- printf "%s-config" $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create the name for a Kubernetes Secret containing Kerberos keytabs.
*/}}
{{- define "krb5-keytabs-secret" -}}
{{- if .Values.global.kerberosKeytabsSecretOverride -}}
{{- .Values.global.kerberosKeytabsSecretOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "hdfs-ci.krb5.fullname" . -}}
{{- printf "%s-keytabs" $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}


{{/*
Create the domain name part of services.
The HDFS config file should specify FQDN of services. Otherwise, Kerberos
login may fail.
*/}}
{{- define "svc-domain" -}}
{{- printf "%s.svc.cluster.local" .Release.Namespace -}}
{{- end -}}

{{/*
Construct the name of the Kerberos KDC pod 0.
*/}}
{{- define "krb5-pod-0" -}}
{{- template "hdfs-ci.krb5.fullname" . -}}-0
{{- end -}}

{{/*
Construct the full name of the Kerberos KDC statefulset member 0.
*/}}
{{- define "krb5-svc-0" -}}
{{- $pod := include "krb5-pod-0" . -}}
{{- $service := include "hdfs-ci.krb5.fullname" . -}}
{{- $domain := include "svc-domain" . -}}
{{- printf "%s.%s.%s" $pod $service $domain -}}
{{- end -}}

{{/*
Construct the name of the namenode pod 0.
*/}}
{{- define "namenode-pod-0" -}}
{{- template "hdfs-ci.namenode.fullname" . -}}-0
{{- end -}}

{{/*
Construct the full name of the namenode statefulset member 0.
*/}}
{{- define "namenode-svc-0" -}}
{{- $pod := include "namenode-pod-0" . -}}
{{- $service := include "hdfs-ci.namenode.fullname" . -}}
{{- $domain := include "svc-domain" . -}}
{{- printf "%s.%s.%s" $pod $service $domain -}}
{{- end -}}

{{/*
Construct the name of the namenode pod 1.
*/}}
{{- define "namenode-pod-1" -}}
{{- template "hdfs-ci.namenode.fullname" . -}}-1
{{- end -}}

{{/*
Construct the full name of the namenode statefulset member 1.
*/}}
{{- define "namenode-svc-1" -}}
{{- $pod := include "namenode-pod-1" . -}}
{{- $service := include "hdfs-ci.namenode.fullname" . -}}
{{- $domain := include "svc-domain" . -}}
{{- printf "%s.%s.%s" $pod $service $domain -}}
{{- end -}}
