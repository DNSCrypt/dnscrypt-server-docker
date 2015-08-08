#! /bin/sh

sleep 1800

KEYS_DIR="/opt/dnscrypt-wrapper/etc/keys"
STKEYS_DIR="${KEYS_DIR}/short-term"

rotation_needed() {
    if [ $(find "$STKEYS_DIR" -type f -cmin -720 -print -quit | wc -l | sed 's/[^0-9]//g') -le 0 ]; then
        echo true
    else
        echo false
    fi
}

[ $(rotation_needed) = true ] || exit 0
sv status dnscrypt-wrapper | egrep -q '^run:' || exit 0
sv restart dnscrypt-wrapper
