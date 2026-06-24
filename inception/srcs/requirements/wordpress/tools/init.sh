#!/bin/sh
set -eu

if [ ! -f "$WORDPRESS_DB_PASSWORD_FILE" ]; then echo "❌ DB password file missing"; exit 1; fi
WORDPRESS_DB_PASSWORD=$(cat "$WORDPRESS_DB_PASSWORD_FILE")

if [ ! -f "$WP_ADMIN_PASSWORD_FILE" ]; then echo "❌ Admin password file missing"; exit 1; fi
WP_ADMIN_PASSWORD=$(cat "$WP_ADMIN_PASSWORD_FILE")

if [ -n "${WP_SECOND_PASSWORD_FILE:-}" ] && [ -f "$WP_SECOND_PASSWORD_FILE" ]; then
  WP_SECOND_PASSWORD=$(cat "$WP_SECOND_PASSWORD_FILE")
fi

echo "==> Waiting for MariaDB to be ready..."
until mariadb-admin ping --protocol=tcp --host="$WORDPRESS_DB_HOST" -u "$WORDPRESS_DB_USER" --password="$WORDPRESS_DB_PASSWORD" --silent; do
  sleep 2
done

if [ ! -f /var/www/html/wp-config.php ]; then
  echo "==> Creating wp-config.php..."
  wp config create \
    --path=/var/www/html \
    --dbname="$WORDPRESS_DB_NAME" \
    --dbuser="$WORDPRESS_DB_USER" \
    --dbpass="$WORDPRESS_DB_PASSWORD" \
    --dbhost="$WORDPRESS_DB_HOST" \
    --dbprefix="wp_" \
    --allow-root
fi

if ! wp core is-installed --path=/var/www/html --allow-root; then
  echo "==> Installing WordPress..."
  wp core install \
    --path=/var/www/html \
    --url="https://${DOMAIN_NAME}" \
    --title="${WP_SITE_TITLE}" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password="${WP_ADMIN_PASSWORD}" \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --skip-email \
    --allow-root

  if [ -n "${WP_SECOND_USER:-}" ] && [ -n "${WP_SECOND_EMAIL:-}" ] && [ -n "${WP_SECOND_PASSWORD:-}" ]; then
    echo "==> Creating second user..."
    wp user create "${WP_SECOND_USER}" "${WP_SECOND_EMAIL}" \
      --path=/var/www/html \
      --user_pass="${WP_SECOND_PASSWORD}" \
      --role="${WP_SECOND_ROLE:-author}" \
      --allow-root
  fi
else
  echo "==> WordPress already installed."
fi

chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

exec "$@"
