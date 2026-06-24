FROM alpine:3.22

RUN apk update && apk add --no-cache \
    nginx \
    openssl \
  && rm -rf /var/cache/apk/*

RUN mkdir -p /etc/nginx/ssl

COPY conf/default.conf /etc/nginx/http.d/default.conf
RUN chmod 644 /etc/nginx/http.d/default.conf

COPY tools/init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 443
ENTRYPOINT ["/init.sh"]
