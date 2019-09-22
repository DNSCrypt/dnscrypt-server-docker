#! /usr/bin/env bash

LEGACY_KEYS_DIR="/opt/dnscrypt-wrapper/etc/keys"
CONF_DIR="/opt/encrypted-dns/etc"
KEYS_DIR="/opt/encrypted-dns/etc/keys"
LISTS_DIR="/opt/encrypted-dns/etc/lists"
BLACKLIST="${LISTS_DIR}/blacklist.txt"
CONFIG_FILE="${CONF_DIR}/encrypted-dns.toml"

if [ ! -f "$KEYS_DIR/provider_name" ]; then
    exit 1
fi
provider_name=$(cat "$KEYS_DIR/provider_name")

exec /opt/encrypted-dns/sbin/encrypted-dns --config "$CONFIG_FILE"
