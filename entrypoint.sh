#! /usr/bin/env bash

set -e

action="$1"

LEGACY_KEYS_DIR="/opt/dnscrypt-wrapper/etc/keys"
LEGACY_LISTS_DIR="/opt/dnscrypt-wrapper/etc/lists"
LEGACY_STATE_DIR="${LEGACY_KEYS_DIR}/state"
KEYS_DIR="/opt/encrypted-dns/etc/keys"
STATE_DIR="${KEYS_DIR}/state"
LISTS_DIR="/opt/encrypted-dns/etc/lists"
CONF_DIR="/opt/encrypted-dns/etc"
CONFIG_FILE="${CONF_DIR}/encrypted-dns.toml"
CONFIG_FILE_TEMPLATE="${CONF_DIR}/encrypted-dns.toml.in"

init() {
    if [ "$(is_initialized)" = yes ]; then
        start
        exit $?
    fi

    anondns_enabled="false"
    anondns_blacklisted_ips=""

    metrics_address="127.0.0.1:9100"

    while getopts "h?N:E:T:S:AM:" opt; do
        case "$opt" in
        h | \?) usage ;;
        N) provider_name=$(echo "$OPTARG" | sed -e 's/^[ \t]*//' | tr A-Z a-z) ;;
        E) ext_address=$(echo "$OPTARG" | sed -e 's/^[ \t]*//' | tr A-Z a-z) ;;
        S) six_address=$(echo "$OPTARG" | sed -e 's/^[ \t]*//' | tr A-Z a-z) ;;
        T) tls_proxy_upstream_address=$(echo "$OPTARG" | sed -e 's/^[ \t]*//' | tr A-Z a-z) ;;
        A) anondns_enabled="true" ;;
        M) metrics_address=$(echo "$OPTARG" | sed -e 's/^[ \t]*//' | tr A-Z a-z) ;;
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

    tls_proxy_configuration=""
    if [ -n "$tls_proxy_upstream_address" ]; then
        tls_proxy_configuration="upstream_addr = \"${tls_proxy_upstream_address}\""
    fi

    domain_blacklist_file="${LISTS_DIR}/blacklist.txt"
    domain_blacklist_configuration=""
    if [ -s "$domain_blacklist_file" ]; then
        domain_blacklist_configuration="domain_blacklist = \"${domain_blacklist_file}\""
    fi

    echo "Provider name: [$provider_name]"

    echo "$provider_name" >"${KEYS_DIR}/provider_name"
    chmod 644 "${KEYS_DIR}/provider_name"

    if [[ "$six_address" ]]; then
        sed -i '20i ,{local = "[::]:443", external = "@EXTERNAL_IPV6@"}' "$CONFIG_FILE_TEMPLATE"
    fi

    sed \
        -e "s#@PROVIDER_NAME@#${provider_name}#" \
        -e "s#@EXTERNAL_IPV4@#${ext_address}#" \
        -e "s#@EXTERNAL_IPV6@#${second_address}#" \
        -e "s#@TLS_PROXY_CONFIGURATION@#${tls_proxy_configuration}#" \
        -e "s#@DOMAIN_BLACKLIST_CONFIGURATION@#${domain_blacklist_configuration}#" \
        -e "s#@ANONDNS_ENABLED@#${anondns_enabled}#" \
        -e "s#@ANONDNS_BLACKLISTED_IPS@#${anondns_blacklisted_ips}#" \
        -e "s#@METRICS_ADDRESS@#${metrics_address}#" \
        "$CONFIG_FILE_TEMPLATE" >"$CONFIG_FILE"

    mkdir -p -m 700 "${STATE_DIR}"
    chown _encrypted-dns:_encrypted-dns "${STATE_DIR}"

    if [ -f "${KEYS_DIR}/secret.key" ]; then
        echo "Importing the previous secret key [${KEYS_DIR}/secret.key]"
        /opt/encrypted-dns/sbin/encrypted-dns \
            --config "$CONFIG_FILE" \
            --import-from-dnscrypt-wrapper "${KEYS_DIR}/secret.key" \
            --dry-run >/dev/null || exit 1
        mv -f "${KEYS_DIR}/secret.key" "${KEYS_DIR}/secret.key.migrated"
    fi

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

legacy_compat() {
    if [ -f "${KEYS_DIR}/provider-info.txt" ] && [ -f "${KEYS_DIR}/provider_name" ]; then
        return 0
    fi
    if [ -f "${LEGACY_KEYS_DIR}/provider-info.txt" ] && [ -f "${LEGACY_KEYS_DIR}/provider_name" ]; then
        echo "Using [${LEGACY_KEYS_DIR}] for keys" >&2
        mkdir -p "${KEYS_DIR}"
        mv -f "${KEYS_DIR}/provider-info.txt" "${KEYS_DIR}/provider-info.txt.migrated" 2>/dev/null || :
        ln -s "${LEGACY_KEYS_DIR}/provider-info.txt" "${KEYS_DIR}/provider-info.txt" 2>/dev/null || :
        mv -f "${KEYS_DIR}/provider_name" "${KEYS_DIR}/provider_name.migrated" 2>/dev/null || :
        ln -s "${LEGACY_KEYS_DIR}/provider_name" "${KEYS_DIR}/provider_name" 2>/dev/null || :
        mv -f "${KEYS_DIR}/secret.key" "${KEYS_DIR}/secret.key.migrated" 2>/dev/null || :
        ln -s "${LEGACY_KEYS_DIR}/secret.key" "${KEYS_DIR}/secret.key" 2>/dev/null || :
        mkdir -p -m 700 "${LEGACY_STATE_DIR}"
        chown _encrypted-dns:_encrypted-dns "${LEGACY_STATE_DIR}"
        mv -f "$STATE_DIR" "${STATE_DIR}.migrated" 2>/dev/null || :
        ln -s "$LEGACY_STATE_DIR" "${STATE_DIR}" 2>/dev/null || :
    fi
    if [ -f "${LEGACY_LISTS_DIR}/blacklist.txt" ]; then
        echo "Using [${LEGACY_LISTS_DIR}] for lists" >&2
        mkdir -p "${LISTS_DIR}"
        mv -f "${LISTS_DIR}/blacklist.txt" "${LISTS_DIR}/blacklist.txt.migrated" 2>/dev/null || :
        ln -s "${LEGACY_LISTS_DIR}/blacklist.txt" "${LISTS_DIR}/blacklist.txt" 2>/dev/null || :
    fi
}

is_initialized() {
    if [ -f "$CONFIG_FILE" ] && [ -f "${STATE_DIR}/encrypted-dns.state" ] && [ -f "${KEYS_DIR}/provider-info.txt" ] && [ -f "${KEYS_DIR}/provider_name" ]; then
        echo yes
    else
        legacy_compat
        if [ -f "$CONFIG_FILE" ] && [ -f "${STATE_DIR}/encrypted-dns.state" ] && [ -f "${KEYS_DIR}/provider-info.txt" ] && [ -f "${KEYS_DIR}/provider_name" ]; then
            echo yes
        else
            echo no
        fi
    fi
}

ensure_initialized() {
    if [ "$(is_initialized)" = no ]; then
        if [ -d "$LEGACY_KEYS_DIR" ]; then
            echo "Please provide an initial configuration (init -N <provider_name> -E <external IP>)" >&2
        fi
        exit 1
    fi
}

start() {
    ensure_initialized
    if [ -f "${KEYS_DIR}/secret.key" ]; then
        echo "Importing the previous secret key [${KEYS_DIR}/secret.key]"
        /opt/encrypted-dns/sbin/encrypted-dns \
            --config "$CONFIG_FILE" \
            --import-from-dnscrypt-wrapper "${KEYS_DIR}/secret.key" \
            --dry-run >/dev/null || exit 1
        mv -f "${KEYS_DIR}/secret.key" "${KEYS_DIR}/secret.key.migrated"
    fi
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

If TLS connections to the same port have to be redirected to a HTTPS server
(e.g. for DoH), add -T <https server ip>:<port>

To enable Anonymized DNS relaying, add -A.

To add an IPV6 address, add -S [<external ipv6>]:port 

* start (default command): start the resolver and the dnscrypt server proxy.
Ports 443/udp and 443/tcp have to be publicly exposed.

* provider-info: prints the provider name and provider public key.

* shell: run a shell.

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
