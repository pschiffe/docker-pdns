{% for key, value in environment('PDNS_') %}{{ key|replace('_', '-') }}={{ value }}
{% endfor %}
