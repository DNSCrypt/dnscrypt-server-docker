#! /bin/sh

set -e

action="$1"

KEYS_DIR="/opt/dnscrypt-wrapper/etc/keys"

# -N provider-name

init() {
    if [ $(is_initialized) = yes ]; then
        start
        exit $?
    fi
    while getopts "h?N:" opt; do
        case "$opt" in
            h|\?) usage ;;
            N) provider_name=$(echo "$OPTARG" | sed -e 's/^[ \t]*//' | tr A-Z a-z) ;;
        esac
    done
    [ -z "$provider_name" ] && usage
    case "$provider_name" in
        .*) usage ;;
        2.dnscrypt-cert.*) ;;
        *) provider_name="2.dnscrypt-cert.${provider_name}"
    esac
    echo "Provider name: [$provider_name]"
    cd "$KEYS_DIR"
    /opt/dnscrypt-wrapper/sbin/dnscrypt-wrapper --gen-provider-keypair | \
        tee "${KEYS_DIR}/provider-info.txt"
    chmod 640 "${KEYS_DIR}/secret.key"
    chmod 644 "${KEYS_DIR}/public.key"
    chown root:_dnscrypt-signer "${KEYS_DIR}/public.key" "${KEYS_DIR}/secret.key"
    echo "$provider_name" > "${KEYS_DIR}/provider_name"
    chmod 644 "${KEYS_DIR}/provider_name"
    hexdump -ve '1/1 "%.2x"' < "${KEYS_DIR}/public.key" > "${KEYS_DIR}/public.key.txt"
    chmod 644 "${KEYS_DIR}/public.key.txt"
    echo
    echo -----------------------------------------------------------------------
    echo
    echo "Congratulations! The container has been properly initialized."
    echo "Take a look up above at the way dnscrypt-proxy has to be configured in order"
    echo "to connect to your resolver. Then, start the container with the default command."
}

provider_info() {
    ensure_initialized
    echo "Provider name:"
    cat "${KEYS_DIR}/provider_name"
    echo
    echo "Provider public key:"
    cat "${KEYS_DIR}/public.key.txt"
    echo
}

is_initialized() {
    if [ ! -f "${KEYS_DIR}/public.key" -a ! -f "${KEYS_DIR}/secret.key" -a ! -f "${KEYS_DIR}/provider_name" ]; then
        echo no
    else
        echo yes
    fi
}

ensure_initialized() {
    if [ $(is_initialized) = no ]; then
        echo "Please provide an initial configuration (init -N <provider_name>)" >&2
        exit 1
    fi
}

start() {
    ensure_initialized
    echo "Starting DNSCrypt service for provider: "
    cat "${KEYS_DIR}/provider_name"
    exec /sbin/start_runit
}

usage() {
    cat << EOT
Commands
========

* init -N <provider_name>: initialize the container for a new provider named <provider_name>
This is supposed to be called only once.

* start (default command): start the resolver and the dnscrypt server proxy.
Ports 443/udp and 443/tcp have to be publicly exposed.

* provider-info: prints the provide name and provider public key.

This container has a single volume that you might want to securely keep a
backup of: /opt/dnscrypt-wrapper/etc/keys
EOT
    exit 1
}

case "$action" in
    start) start ;;
    init) shift ; init $* ;;
    provider-info) provider_info ;;
    *) usage ;;
esac
