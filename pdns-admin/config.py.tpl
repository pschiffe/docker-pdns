import os
basedir = os.path.abspath(os.path.dirname(__file__))

{% for key, value in environment('PDNS_ADMIN_') %}{{ key }} = {{ value }}
{% endfor %}

WTF_CSRF_ENABLED = True
BIND_ADDRESS = '0.0.0.0'
PORT = 9393
LOG_FILE = '/dev/null'
UPLOAD_DIR = '/opt/powerdns-admin/upload'
SQLALCHEMY_DATABASE_URI = 'mysql://' + SQLA_DB_USER + ':' + SQLA_DB_PASSWORD + '@' + SQLA_DB_HOST + ':' + SQLA_DB_PORT + '/' + SQLA_DB_NAME
SQLALCHEMY_MIGRATE_REPO = os.path.join(basedir, 'db_repository')
SQLALCHEMY_TRACK_MODIFICATIONS = True
