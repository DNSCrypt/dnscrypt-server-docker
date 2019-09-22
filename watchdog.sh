#! /usr/bin/env bash

sleep 300

for service in unbound encrypted-dns; do
    sv check "$service" || sv force-restart "$service"
done

KEYS_DIR="/opt/encrypted-dns/etc/keys"
GRACE_PERIOD=60

provider_name=$(cat "${KEYS_DIR}/provider_name")

drill -p 443 -Q TXT "$provider_name" @127.0.0.1 ||
    sv force-restart encrypted-dns
