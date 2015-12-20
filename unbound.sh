#! /bin/sh

KEYS_DIR="/opt/dnscrypt-wrapper/etc/keys"

reserved=12582912
availableMemory=$((1024 * $(fgrep MemAvailable /proc/meminfo | sed 's/[^0-9]//g') - $reserved))
if [ $availableMemory -le 0 ]; then
    exit 1
fi
msg_cache_size=$(($availableMemory / 3))
rr_cache_size=$(($availableMemory / 3))
nproc=$(nproc)
if [ $nproc -gt 1 ]; then
    threads=$(($nproc - 1))
else
    threads=1
fi

provider_name=$(cat "$KEYS_DIR/provider_name")

sed \
    -e "s/@MSG_CACHE_SIZE@/${msg_cache_size}/" \
    -e "s/@PROVIDER_NAME@/${provider_name}/" \
    -e "s/@RR_CACHE_SIZE@/${rr_cache_size}/" \
    -e "s/@THREADS@/${threads}/" \
    > /opt/unbound/etc/unbound/unbound.conf << EOT
server:
  verbosity: 1
  num-threads: @THREADS@
  interface: 127.0.0.1@553
  so-reuseport: yes
  edns-buffer-size: 1252
  delay-close: 10000
  cache-min-ttl: 60
  cache-max-ttl: 86400
  do-daemonize: no
  username: "_unbound"
  log-queries: no
  hide-version: yes
  identity: "DNSCrypt"
  harden-short-bufsize: yes
  harden-large-queries: yes
  harden-glue: yes
  harden-dnssec-stripped: yes
  harden-below-nxdomain: yes
  harden-referral-path: no
  do-not-query-localhost: no
  prefetch: yes
  prefetch-key: yes
  qname-minimisation: yes
  ratelimit: 1000
  rrset-roundrobin: yes
  minimal-responses: yes
  chroot: "/opt/unbound/etc/unbound"
  directory: "/opt/unbound/etc/unbound"
  auto-trust-anchor-file: "var/root.key"
  num-queries-per-thread: 4096
  outgoing-range: 8192
  msg-cache-size: @MSG_CACHE_SIZE@
  rrset-cache-size: @RR_CACHE_SIZE@
  neg-cache-size: 4M
  access-control: 0.0.0.0/0 allow
  access-control: ::0/0 allow

  local-zone: "belkin." static
  local-zone: "corp." static
  local-zone: "domain." static
  local-zone: "example." static
  local-zone: "home." static
  local-zone: "host." static
  local-zone: "invalid." static
  local-zone: "lan." static
  local-zone: "local." static
  local-zone: "localdomain." static
  local-zone: "test." static
  local-zone: "@PROVIDER_NAME@." refuse

remote-control:
  control-enable: yes
  control-interface: 127.0.0.1
  control-interface: ::1
EOT

mkdir -p /opt/unbound/etc/unbound/dev && \
cp -a /dev/random /dev/urandom /opt/unbound/etc/unbound/dev/

mkdir -p -m 700 /opt/unbound/etc/unbound/var && \
chown _unbound:_unbound /opt/unbound/etc/unbound/var && \
/opt/unbound/sbin/unbound-anchor -a /opt/unbound/etc/unbound/var/root.key

if [ ! -f /opt/unbound/etc/unbound/unbound_control.pem ]; then
  /opt/unbound/sbin/unbound-control-setup
fi

exec /opt/unbound/sbin/unbound
