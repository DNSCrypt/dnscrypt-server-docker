#! /usr/bin/env bash

CONF_DIR="/opt/encrypted-dns/etc"
KEYS_DIR="/opt/encrypted-dns/etc/keys"
CONFIG_FILE="${CONF_DIR}/encrypted-dns.toml"

if [ ! -f "$KEYS_DIR/provider_name" ]; then
    exit 1
fi

exec /opt/encrypted-dns/sbin/encrypted-dns --config "$CONFIG_FILE"
