#!/bin/sh
set -eu

cd /opt/ircenter

docker compose run --rm certbot renew --quiet

if docker exec ircenter-web nginx -t; then
    docker exec ircenter-web nginx -s reload
fi
