#!/bin/bash

if [[ ! -z "$USE_NGINX" ]]; then
    export SSL_CERTIFICATE=${NGINX_SSL_CERTIFICATE:=/etc/ssl/nginx/tls.crt}
    export SSL_CERTIFICATE_KEY=${NGINX_SSL_CERTIFICATE_KEY:=/etc/ssl/nginx/tls.key}
    export UPSTREAM_URI=${NGINX_UPSTREAM_URI:=localhost:8000}
    CONFIG_TEMPLATE=${NGINX_CONFIG_TEMPLATE:=/etc/nginx/nginx.conf.base}
    CONFIG_OUT=${NGINX_CONFIG_OUT:=/etc/nginx/nginx.conf}

    envsubtopts='$SSL_CERTIFICATE:$SSL_CERTIFICATE_KEY:$UPSTREAM_URI'

    envsubst "$envsubtopts" < "$CONFIG_TEMPLATE" > "$CONFIG_OUT"

    echo "starting nginx"
    exec nginx -g 'daemon off;'
fi
