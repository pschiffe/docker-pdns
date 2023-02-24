import os
basedir = os.path.abspath(os.path.dirname(__file__))

### BASIC APP CONFIG
BIND_ADDRESS = '0.0.0.0'
PORT = 9191
HSTS_ENABLED = False

# CAPTCHA Config
CAPTCHA_ENABLE = True
CAPTCHA_LENGTH = 6
CAPTCHA_WIDTH = 160
CAPTCHA_HEIGHT = 60
CAPTCHA_SESSION_KEY = 'captcha_image'

# Server side sessions tracking
# Set to TRUE for CAPTCHA, or enable another stateful session tracking system
FILESYSTEM_SESSIONS_ENABLED = True

# SAML Authnetication
SAML_ENABLED = False

{% for key, value in environment('PDNS_ADMIN_') %}{{ key }} = {{ value }}
{% endfor %}

### DATABASE CONFIG
SQLALCHEMY_DATABASE_URI = 'mysql://' + SQLA_DB_USER + ':' + SQLA_DB_PASSWORD + '@' + SQLA_DB_HOST + ':' + SQLA_DB_PORT + '/' + SQLA_DB_NAME
SQLALCHEMY_TRACK_MODIFICATIONS = True
