import os
basedir = os.path.abspath(os.path.dirname(__file__))

### BASIC APP CONFIG
BIND_ADDRESS = '0.0.0.0'
PORT = 9191
HSTS_ENABLED = False

# SAML Authnetication
SAML_ENABLED = False

{% for key, value in environment('PDNS_ADMIN_') %}{{ key }} = {{ value }}
{% endfor %}

### DATABASE CONFIG
SQLALCHEMY_DATABASE_URI = 'mysql://' + SQLA_DB_USER + ':' + SQLA_DB_PASSWORD + '@' + SQLA_DB_HOST + ':' + SQLA_DB_PORT + '/' + SQLA_DB_NAME
SQLALCHEMY_TRACK_MODIFICATIONS = True
