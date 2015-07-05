#! /bin/sh

sleep 600

for service in unbound dnscrypt-wrapper; do
    sv check "$service" || sv force-restart "$service"
done

KEYS_DIR="/opt/dnscrypt-wrapper/etc/keys"
GRACE_PERIOD=600

provider_key=$(cat "${KEYS_DIR}/public.key.txt")
provider_name=$(cat "${KEYS_DIR}/provider_name")

(/opt/dnscrypt-proxy/sbin/dnscrypt-proxy \
    --user=_dnscrypt-proxy \
    --provider-key="$provider_key" \
    --provider-name="$provider_name" \
    --resolver-address=127.0.0.1:443 \
    --test="$GRACE_PERIOD" && \
drill -p 443 -Q TXT "$provider_name" @127.0.0.1) || \
sv force-restart dnscrypt-wrapper
