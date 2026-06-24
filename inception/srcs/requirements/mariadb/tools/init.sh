#!/bin/sh
set -eu

trim_file() { tr -d '\r\n' < "$1"; }
need() { eval "v=\${$1:-}"; [ -n "$v" ] || { echo "❌ Missing env: $1" >&2; exit 1; }; }

need MYSQL_DATABASE
need MYSQL_USER
need MYSQL_ROOT_PASSWORD_FILE
need MYSQL_PASSWORD_FILE

MYSQL_ROOT_PASSWORD="$(trim_file "$MYSQL_ROOT_PASSWORD_FILE")"
MYSQL_PASSWORD="$(trim_file "$MYSQL_PASSWORD_FILE")"
DATADIR="/var/lib/mysql"

if [ ! -d "${DATADIR}/mysql" ]; then
  mariadb-install-db --user=mysql --basedir=/usr --datadir="$DATADIR" >/dev/null
  mariadbd --user=mysql --bootstrap --datadir="$DATADIR" <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
DELETE FROM mysql.user WHERE user='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF
fi

exec mariadbd-safe
