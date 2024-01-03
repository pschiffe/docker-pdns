{{ range $key, $value := match "PDNS_" -}}
{{- $key | trimPrefix "PDNS_" | replace "_" "-" }} = {{ $value }}
{{ end -}}
