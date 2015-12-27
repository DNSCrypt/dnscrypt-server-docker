#! /bin/sh

KEYS_DIR="/opt/dnscrypt-wrapper/etc/keys"
provider_name=$(cat "$KEYS_DIR/provider_name")

sed \
    -e "s/@PROVIDER_NAME@/${provider_name}/" \
    > /opt/unbound/etc/unbound/unbound.conf << EOT
server:
  infra-cache-slabs: 2
  msg-cache-slabs: 2
  rrset-cache-slabs: 2
  key-cache-slabs: 2
  ratelimit-slabs: 2
  so-rcvbuf: 8m
  so-sndbuf: 8m
  key-cache-size: 32m
  infra-cache-numhosts: 100000
  infra-host-ttl: 1800
  extended-statistics: yes
  do-ip4: yes
  do-ip6: no
  do-udp: yes
  do-tcp: yes
  access-control: 127.0.0.1 allow
  access-control: ::1 allow
  val-clean-additional: yes
  verbosity: 1
  num-threads: 2
  interface: 127.0.0.1@553
  so-reuseport: yes
  edns-buffer-size: 1252
  delay-close: 10000
  cache-min-ttl: 3600
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
  msg-cache-size: 512m
  rrset-cache-size: 1024m
  neg-cache-size: 8m

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
  
  include: /opt/unbound/etc/unbound-ad-servers.txt

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
