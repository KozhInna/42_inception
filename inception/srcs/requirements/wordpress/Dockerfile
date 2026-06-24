FROM alpine:3.22

RUN apk update && apk add --no-cache \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-mbstring \
    php83-dom \
    php83-gd \
    php83-zip \
    php83-curl \
    php83-phar \
    php83-iconv \
    php83-json \
    curl \
    tar \
    mariadb-client \
 && rm -rf /var/cache/apk/*

RUN mkdir -p /var/www/html

WORKDIR /var/www/html

RUN curl -O https://wordpress.org/latest.tar.gz && \
    tar -xzf latest.tar.gz && \
    mv wordpress/* . && \
    rm -rf wordpress latest.tar.gz

RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
 && chmod +x /usr/local/bin/wp

COPY conf/www.conf /etc/php83/php-fpm.d/www.conf

RUN adduser -D -H -s /sbin/nologin -g www-data -G www-data www-data

COPY tools/init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 9000
ENTRYPOINT ["/init.sh"]
CMD ["php-fpm83", "-F"]
