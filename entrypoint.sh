#! /usr/bin/env bash

set -e

action="$1"

LEGACY_KEYS_DIR="/opt/dnscrypt-wrapper/etc/keys"
LEGACY_LISTS_DIR="/opt/dnscrypt-wrapper/etc/lists"
KEYS_DIR="/opt/encrypted-dns/etc/keys"
LISTS_DIR="/opt/encrypted-dns/etc/lists"
CONF_DIR="/opt/encrypted-dns/etc"
CONFIG_FILE="${CONF_DIR}/encrypted-dns.toml"
CONFIG_FILE_TEMPLATE="${CONF_DIR}/encrypted-dns.toml.in"

# -N provider-name -E external-ip-address:port

init() {
    if [ "$(is_initialized 2>/dev/null)" = yes ]; then
        start
        exit $?
    fi

    while getopts "h?N:E:T:" opt; do
        case "$opt" in
        h | \?) usage ;;
        N) provider_name=$(echo "$OPTARG" | sed -e 's/^[ \t]*//' | tr A-Z a-z) ;;
        E) ext_address=$(echo "$OPTARG" | sed -e 's/^[ \t]*//' | tr A-Z a-z) ;;
        T) tls_proxy_upstream_address=$(echo "$OPTARG" | sed -e 's/^[ \t]*//' | tr A-Z a-z) ;;
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

    sed \
        -e "s#@PROVIDER_NAME@#${provider_name}#" \
        -e "s#@EXTERNAL_IPV4@#${ext_address}#" \
        -e "s#@TLS_PROXY_CONFIGURATION@#${tls_proxy_configuration}#" \
        -e "s#@DOMAIN_BLACKLIST_CONFIGURATION@#${domain_blacklist_configuration}#" \
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
        echo "Neither [${KEYS_DIR}] doesn't seem to contain the required DNS provider information, and a [${LEGACY_KEYS_DIR}] directory wasn't found either" >&2
        return 1
    fi
    echo "Legacy [$LEGACY_KEYS_DIR] directory found" >&2
    if [ -d "${KEYS_DIR}/provider_name" ]; then
        echo "Both [${LEGACY_KEYS_DIR}] and [${KEYS_DIR}] are present and not empty - This is not expected." >&2
        return 1
    fi
    if [ ! -f "${LEGACY_KEYS_DIR}/secret.key" ]; then
        echo "No secret key in [${LEGACY_KEYS_DIR}/secret.key], this is not expected." >&2
        echo >&2
        echo "If you are migrating from a container previously running dnscrypt-wrapper," >&2
        echo "make sure that the [${LEGACY_KEYS_DIR}] directory is mounted." >&2
        echo >&2
        echo "If you are setting up a brand new server, maybe you've been following" >&2
        echo "an outdated tutorial." >&2
        echo >&2
        echo "The key directory should be mounted as [${KEYS_DIR}] and not [$LEGACY_KEYS_DIR]." >&2
        return 1
    fi
    echo "...and this is fine! You can keep using it, no need to change anything to your Docker volumes." >&2
    echo "We'll just copy a few things to [${KEYS_DIR}] internally" >&2
    find "$KEYS_DIR" -type f -print -exec cp -afv {} "$LEGACY_KEYS_DIR/" \;
    chmod 700 "$LEGACY_KEYS_DIR"
    chown -R _encrypted-dns:_encrypted-dns "$LEGACY_KEYS_DIR"
    echo "...and update the configuration file" >&2
    sed -e "s#${KEYS_DIR}#${LEGACY_KEYS_DIR}#g" <"$CONFIG_FILE_TEMPLATE" >"${CONFIG_FILE_TEMPLATE}.tmp" &&
        mv -f "${CONFIG_FILE_TEMPLATE}.tmp" "$CONFIG_FILE_TEMPLATE" || exit 1
    provider_name=$(cat "${LEGACY_KEYS_DIR}/provider_name")
    if [ -f "${LEGACY_KEYS_DIR}/provider-info.txt" ]; then
        ext_address=$(grep -F -- "--resolver-address=" "${LEGACY_KEYS_DIR}/provider-info.txt" 2>/dev/null | cut -d'=' -f2 | sed 's/ //g')
    fi
    if [ -z "$ext_address" ]; then
        echo "(we were not able to find the previous external IP address, the printed stamp will be wrong, but the previous stamp will keep working)" >&2
        ext_address="0.0.0.0:443"
    fi

    tls_proxy_configuration=""
    domain_blacklist_file="${LISTS_DIR}/blacklist.txt"
    domain_blacklist_configuration=""
    if [ -s "$domain_blacklist_file" ]; then
        domain_blacklist_configuration="domain_blacklist = \"${domain_blacklist_file}\""
    fi
    sed \
        -e "s#@PROVIDER_NAME@#${provider_name}#" \
        -e "s#@EXTERNAL_IPV4@#${ext_address}#" \
        -e "s#@TLS_PROXY_CONFIGURATION@#${tls_proxy_configuration}#" \
        -e "s#@DOMAIN_BLACKLIST_CONFIGURATION@#${domain_blacklist_configuration}#" \
        "$CONFIG_FILE_TEMPLATE" >"$CONFIG_FILE"
    echo "...and check that everything's fine..." >&2
    /opt/encrypted-dns/sbin/encrypted-dns \
        --config "$CONFIG_FILE" \
        --import-from-dnscrypt-wrapper "${LEGACY_KEYS_DIR}/secret.key" \
        --dry-run >/dev/null || exit 1
    chmod 600 "${LEGACY_KEYS_DIR}/secret.key"
    echo "Done!" >&2
    echo >&2

    if [ -s "${LEGACY_LISTS_DIR}/blacklist.txt" ]; then
        echo "Your blacklist [${LEGACY_LISTS_DIR}/blacklist.txt] will be loaded as well." >&2
    fi

    export KEYS_DIR="$LEGACY_KEYS_DIR"
    export LISTS_DIR="$LEGACY_LISTS_DIR"
}

is_initialized() {
    if [ ! -f "${KEYS_DIR}/encrypted-dns.state" ] || [ ! -f "${KEYS_DIR}/provider-info.txt" ] || [ ! -f "${KEYS_DIR}/provider_name" ]; then
        if dnscrypt_wrapper_compat; then
            if [ ! -f "${KEYS_DIR}/encrypted-dns.state" ] || [ ! -f "${KEYS_DIR}/provider_name" ]; then
                echo no
            else
                echo yes
            fi
        else
            echo no
        fi
    else
        echo yes
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
