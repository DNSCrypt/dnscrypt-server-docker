#!/usr/bin/env bash

set -x

yum -y update

SERVER="$(hostname)"
export SERVER
SERVER_IP="$(ip route get 1 | awk '{print $NF;exit}')"
export SERVER_IP
echo "$SERVER"
echo "$SERVER_IP"

(
    exec 2>/dev/null

	if ! [ -x "$(command -v docker)" ]; then
		yum install -y docker
	fi

    docker stop dnscrypt-server
    docker stop watchtower
    docker rm dnscrypt-server
    docker rm watchtower
    docker container prune -f
    docker volume prune -f
    docker image prune -f

    yum remove -y firewalld
    yum remove -y iptables-services
)

mkdir -p /etc/encrypted-dns/lists
if [ -d /root/keys ]; then
    mv /root/keys /etc/encrypted-dns
fi
mkdir -p /etc/encrypted-dns/keys

rm -fr /etc/encrypted-dns/keys/short-term

if [ -f /etc/encrypted-dns/keys/secret.key ]; then
    docker run \
        --ulimit nofile=90000:90000 \
        -v /etc/encrypted-dns/keys:/opt/encrypted-dns/etc/keys \
        -v /etc/encrypted-dns/lists:/opt/encrypted-dns/etc/lists \
        --name=dnscrypt-server -p 443:443/udp -p 443:443/tcp --net=host \
        -d jedisct1/dnscrypt-server start
else
    docker run \
        --ulimit nofile=90000:90000 \
        -v /etc/encrypted-dns/keys:/opt/encrypted-dns/etc/keys \
        -v /etc/encrypted-dns/lists:/opt/encrypted-dns/etc/lists \
        --name=dnscrypt-server -p 443:443/udp -p 443:443/tcp --net=host \
        jedisct1/dnscrypt-server init -N "$SERVER" -E "${SERVER_IP}:443"
    docker start dnscrypt-server
fi

cat /etc/encrypted-dns/keys/provider-info.txt

docker update --restart=unless-stopped dnscrypt-server

docker run -d --name watchtower -v /var/run/docker.sock:/var/run/docker.sock v2tec/watchtower dnscrypt-server
docker update --restart=unless-stopped watchtower

ln -sf /etc/encrypted-dns/keys /root

echo 3 >/proc/sys/vm/drop_caches

if [ ! -L /etc/motd ]; then
    rm -f /etc/motd
    ln -s /etc/encrypted-dns/keys/provider-info.txt /etc/motd
    reboot
fi
