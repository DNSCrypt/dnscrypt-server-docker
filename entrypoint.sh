#! /usr/bin/env bash

set -e

action="$1"

LEGACY_KEYS_DIR="/opt/dnscrypt-wrapper/etc/keys"
KEYS_DIR="/opt/encrypted-dns/etc/keys"
CONF_DIR="/opt/encrypted-dns/etc"
CONFIG_FILE="${CONF_DIR}/encrypted-dns.toml"
CONFIG_FILE_TEMPLATE="${CONF_DIR}/encrypted-dns.toml.in"

# -N provider-name -E external-ip-address:port

init() {
    if [ "$(is_initialized)" = yes ]; then
        start
        exit $?
    fi
    while getopts "h?N:E:" opt; do
        case "$opt" in
        h | \?) usage ;;
        N) provider_name=$(echo "$OPTARG" | sed -e 's/^[ \t]*//' | tr A-Z a-z) ;;
        E) ext_address=$(echo "$OPTARG" | sed -e 's/^[ \t]*//' | tr A-Z a-z) ;;
        esac
    done
    [ -z "$provider_name" ] && usage
    case "$provider_name" in
    .*) usage ;;
    2.dnscrypt-cert.*) ;;
    *) provider_name="2.dnscrypt-cert.${provider_name}" ;;
    esac

    [ -z "$ext_address" ] && usage
    case "$ext_address" in
    .*) usage ;;
    0.*)
        echo "Do not use 0.0.0.0, use an actual external IP address" >&2
        exit 1
        ;;
    esac

    echo "Provider name: [$provider_name]"

    echo "$provider_name" >"${KEYS_DIR}/provider_name"
    chmod 644 "${KEYS_DIR}/provider_name"

    sed \
        -e "s/@PROVIDER_NAME@/${provider_name}/" \
        -e "s/@EXTERNAL_IPV4@/${ext_address}/" \
        "$CONFIG_FILE_TEMPLATE" >"$CONFIG_FILE"

    /opt/encrypted-dns/sbin/encrypted-dns \
        --config "$CONFIG_FILE" --dry-run |
        tee "${KEYS_DIR}/provider-info.txt"

    echo
    echo -----------------------------------------------------------------------
    echo
    echo "Congratulations! The container has been properly initialized."
    echo "Take a look up above at the way dnscrypt-proxy has to be configured in order"
    echo "to connect to your resolver. Then, start the container with the default command."
}

provider_info() {
    ensure_initialized
    echo
    cat "${KEYS_DIR}/provider-info.txt"
    echo
}

dnscrypt_wrapper_compat() {
    if [ ! -d "$LEGACY_KEYS_DIR" ]; then
        return
    fi
    echo "Legacy [$LEGACY_KEYS_DIR] directory found."
    if [ -d "$KEYS_DIR" ]; then
        echo "Both [${LEGACY_KEYS_DIR}] and [${KEYS_DIR}] are present - This is not expected" >&2
        exit 1
    else
        echo "We'll just symlink it to [${KEYS_DIR}] internally"
        ln -s "${LEGACY_KEYS_DIR}" "$KEYS_DIR"
    fi
    if [ ! -f "${LEGACY_KEYS_DIR}/secret.key" ]; then
        echo "No secret key in [${LEGACY_KEYS_DIR}/secret.key], this is not expected." >&2
    fi
    echo "...and this is fine! You can keep using it, no need to change anything to your Docker volumes."
}

is_initialized() {
    dnscrypt_wrapper_compat
    if [ ! -f "${KEYS_DIR}/encrypted-dns.state" ] && [ ! -f "${KEYS_DIR}/provider-info.txt" ] && [ ! -f "${KEYS_DIR}/provider_name" ]; then
        echo no
    else
        echo yes
    fi
}

ensure_initialized() {
    if [ "$(is_initialized)" = no ]; then
        echo "Please provide an initial configuration (init -N <provider_name> -E <external IP>)" >&2
        exit 1
    fi
}

start() {
    ensure_initialized
    /opt/encrypted-dns/sbin/encrypted-dns \
        --config "$CONFIG_FILE" --dry-run |
        tee "${KEYS_DIR}/provider-info.txt"
    exec /etc/runit/2 </dev/null >/dev/null 2>/dev/null
}

shell() {
    exec /bin/bash
}

usage() {
    cat <<EOT
Commands
========

* init -N <provider_name> -E <external ip>:<port>
initialize the container for a server accessible at ip <external ip> on port
<port>, for a provider named <provider_name>. This is required only once.

* start (default command): start the resolver and the dnscrypt server proxy.
Ports 443/udp and 443/tcp have to be publicly exposed.

* provider-info: prints the provider name and provider public key.

* shell: run a shell

This container has a single volume that you might want to securely keep a
backup of: /opt/encrypted-dns/etc/keys
EOT
    exit 1
}

case "$action" in
start) start ;;
init)
    shift
    init "$@"
    ;;
provider-info) provider_info ;;
shell) shell ;;
*) usage ;;
esac
