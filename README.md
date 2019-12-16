[![Travis Status](https://travis-ci.org/DNSCrypt/dnscrypt-server-docker.svg?branch=master)](https://travis-ci.org/DNSCrypt/dnscrypt-server-docker/builds/)
[![DNSCrypt](https://raw.github.com/jedisct1/dnscrypt-server-docker/master/dnscrypt-small.png)](https://dnscrypt.info)
[![Gitter chat](https://badges.gitter.im/gitter.svg)](https://gitter.im/dnscrypt-operators/Lobby)

# DNSCrypt server Docker image

Run your own caching, non-censoring, non-logging, DNSSEC-capable,
[DNSCrypt](https://dnscrypt.info)-enabled DNS resolver virtually anywhere!

If you are already familiar with Docker, it shouldn't take more than 5 minutes
to get your resolver up and running.

Table of contents:

- [DNSCrypt server Docker image](#dnscrypt-server-docker-image)
- [Example installation procedures](#example-installation-procedures)
- [Installation](#installation)
  - [Updating the container](#updating-the-container)
  - [Anonymized DNS](#anonymized-dns)
  - [Prometheus metrics](#prometheus-metrics)
  - [TLS (including HTTPS and DoH) forwarding](#tls-including-https-and-doh-forwarding)
  - [Filtering](#filtering)
- [Join the network](#join-the-network)
- [Usage with Kubernetes](#usage-with-kubernetes)
- [Customizing Unbound](#customizing-unbound)
  - [Changing the Unbound configuration file](#changing-the-unbound-configuration-file)
  - [Serving custom DNS records on a local network](#serving-custom-dns-records-on-a-local-network)
  - [Troubleshooting](#troubleshooting)
- [Deleting everything](#deleting-everything)
- [Details](#details)

# Example installation procedures

- [How to setup your own DNSCrypt server in less than 10 minutes on Scaleway](https://github.com/dnscrypt/dnscrypt-proxy/wiki/How-to-setup-your-own-DNSCrypt-server-in-less-than-10-minutes)
- [DNSCrypt server with vultr.com](https://github.com/dnscrypt/dnscrypt-proxy/wiki/DNSCrypt-server-with-vultr.com)

# Installation

Think about a name. This is going to be part of your DNSCrypt provider name.
If you are planning to make your resolver publicly accessible, this name will
be public.
By convention, it has to look like a domain name (`example.com`), but it doesn't
have to be an actual, registered domain.

Let's pick `example.com` here.

You probably need to perform the following steps as `root`.

Create a directory where the server is going to store internal data such as secret keys.
Here, we'll use `/etc/dnscrypt-server`:

```sh
mkdir -p /etc/dnscrypt-server/keys
```

Download, create and initialize the container:

```sh
docker run --name=dnscrypt-server -p 443:443/udp -p 443:443/tcp --net=host \
--ulimit nofile=90000:90000 --restart=unless-stopped \
-v /etc/dnscrypt-server/keys:/opt/encrypted-dns/etc/keys \
jedisct1/dnscrypt-server init -N example.com -E '192.168.1.1:443'
```

This will only accept connections via DNSCrypt on the standard port (443). Replace
`192.168.1.1` with the actual external IP address (not the internal Docker one)
clients will connect to.

IPv6 addresses should be enclosed in brackets; for example: `[2001:0db8::412f]:443`.

Multiple comma-separated IPs and ports can be specified, as in `-E '192.168.1.1:443,[2001:0db8::412f]:443'`.

If you want to use a different port, replace all occurrences of `443` with the alternative port in the
command above (including `-p ...`). But if you have an existing website that should be accessible on
port `443`, the server can transparently relay non-DNS traffic to it (see below).

`--net=host` provides the best network performance, but may have to be
removed on some shared containers hosting services.

`-v /etc/dnscrypt-server:/opt/encrypted-dns/etc/keys` means that the path `/opt/encrypted-dns/etc/keys`, internal to the container, is mapped to `/etc/dnscrypt-server/keys`, the directory we just created before. Do not change `/opt/encrypted-dns/etc/keys`. But if you created a directory in a different location, replace `/etc/dnscrypt-server/keys` accordingly in the command above.

__Note:__ on MacOS, don't use `-v ...:...`. Remove that part from the command-line, as current versions of MacOS and Docker don't seem to work well with shared directories.

The `init` command will print the DNS stamp of your server.

Now, to start the whole stack:

```sh
docker start dnscrypt-server
```

Done.

You can verify that the server is running with:

```sh
docker ps
```

Note: if you previously created a container with the same name, and Docker complains that the name is already in use, remove it and try again:

```sh
docker rm --force dnscrypt-server
```

## Updating the container

In order to install the latest version of the image, or change parameters, use the following steps:

1. Update the image

```sh
docker pull jedisct1/dnscrypt-server
```

2. Verify that the directory containing the keys actually has the keys (a `state` directory):

```sh
ls -l /etc/dnscrypt-server/keys
```

If you have some content here, skip to step 3.

Nothing here? Maybe you didn't use the `-v` option to map container files to a local directory when creating the container.
In that case, copy the data directly from the container:

```sh
docker cp dnscrypt-server:/opt/encrypted-dns/etc/keys ~/keys
```

3. Stop the existing container:

```sh
docker stop dnscrypt-server
docker ps # Check that it's not running
```

4. Rename the existing container:

```sh
docker rename dnscrypt-server dnscrypt-server-old
```

5. Use the `init` command again and start the new container:

```sh
docker run --name=dnscrypt-server -p 443:443/udp -p 443:443/tcp --net=host \
--ulimit nofile=90000:90000 --restart=unless-stopped \
-v /etc/dnscrypt-server/keys:/opt/encrypted-dns/etc/keys \
jedisct1/dnscrypt-server init -N example.com -E '192.168.1.1:443'
# (adjust accordingly)

docker start dnscrypt-server
docker ps # Check that it's running
```

6. Delete old container:

```sh
docker rm dnscrypt-server-old
```

7. Done!

Parameters differ from the ones used in the previous container.

For example, if you originally didn't activate relaying
but want to enable it, append `-A` to the command. Or if you want to enable
metrics, append `-M 0.0.0.0:9100` to the end, and `-p 9100:9100/tcp` after
`-p 443:443/tcp` (see below).

## Anonymized DNS

The server can be configured as a relay for the Anonymized DNSCrypt protocol by adding the `-A` switch to the `init` command.

The relay DNS stamp will be printed right after the regular stamp.

## Prometheus metrics

Metrics are accessible inside the container as http://127.0.0.1:9100/metrics.

They can be made accessible outside of the container by adding the `-M` option followed by the listening IP and port (for example: `-M 0.0.0.0:9100`).

These metrics can be indexed with [Prometheus](https://prometheus.io/) and dashboards can be created with [Grafana](https://grafana.com/).

## TLS (including HTTPS and DoH) forwarding

If the DNS server is listening to port `443`, but you still want to have a web (or DoH) service accessible on that port, add the `-T` switch followed by the backend server IP and port to the `init` command (for example: `-T 10.0.0.1:4443`).

The backend server must support the HTTP/2 protocol.

## Filtering

The server can be used block domains. For example, the `sfw.scaleway-fr` server uses that feature to provide a service that blocks websites possibly not suitable for children.

In order to do so, create a directory that will contain the blacklists:

```sh
mkdir -p /etc/dnscrypt-server/lists
```

And put the list of domains to block in a file named `/etc/dnscrypt-server/lists/blacklist.txt`, one domain per line.

Then, follow the upgrade procedure, adding the following option to the `docker run` command: `-v /etc/dnscrypt-server/lists:/opt/encrypted-dns/etc/lists`.

# Join the network

If you want to help against DNS centralization and surveillance,
announce your server and/or relay on the list of [public DNS DoH and DNSCrypt servers](https://dnscrypt.info/public-servers).

The best way to do so is to send a pull request to the
[dnscrypt-resolvers](https://github.com/DNSCrypt/dnscrypt-resolvers/) repository.

# Usage with Kubernetes

Kubernetes configurations are located in the `kube` directory. Currently these assume
a persistent disk named `dnscrypt-keys` on GCE. You will need to adjust the volumes
definition on other platforms. Once that is setup, you can have a dnscrypt server up
in minutes.

- Create a static IP on GCE. This will be used for the LoadBalancer.
- Edit `kube/dnscrypt-init-job.yml`. Change `example.com` to your desired hostname
and `192.0.2.53` to your static IP.
- Edit `kube/dnscrypt-srv.yml` and change `loadBalancerIP` to your static IP.
- Run `kubectl create -f kube/dnscrypt-init-job.yml` to setup your keys.
- Run `kubectl create -f kube/dnscrypt-deployment.yml` to deploy the dnscrypt server.
- Run `kubectl create -f kube/dnscrypt-srv.yml` to expose your server to the world.

To get your public key just view the logs for the `dnscrypt-init` job. The public
IP for your server is merely the `dnscrypt` service address.

# Customizing Unbound

## Changing the Unbound configuration file

To add new configuration to Unbound, add files to the `/opt/unbound/etc/unbound/zones`
directory. All files ending in `.conf` will be processed. In this manner, you
can add any directives to the `server:` section of the Unbound configuration.

## Serving custom DNS records on a local network

While Unbound is not a full authoritative name server, it supports resolving
custom entries in a way that is serviceable on a small, private LAN. You can use
unbound to resolve private hostnames such as `my-computer.example.com` within
your LAN.

To support such custom entries using this image, first map a volume to the zones
directory. Add this to your `docker run` line:

```text
-v /etc/dnscrypt-server/zones:/opt/unbound/etc/unbound/zones
```

The whole command to create and initialize a container would look something like
this:

```sh
docker run --name=dnscrypt-server \
    -v /etc/dnscrypt-server/zones:/opt/unbound/etc/unbound/zones \
    -p 443:443/udp -p 443:443/tcp --net=host \
    jedisct1/dnscrypt-server init -N example.com -E '192.168.1.1:443'
```

Create a new `.conf` file:

```sh
touch /etc/dnscrypt-server/zones/example.conf
```

Now, add one or more unbound directives to the file, such as:

```text
local-zone: "example.com." static
local-data: "my-computer.example.com. IN A 10.0.0.1"
local-data: "other-computer.example.com. IN A 10.0.0.2"
```

## Troubleshooting

If Unbound doesn't like one of the newly added directives, it
will probably not respond over the network. In that case, here are some commands
to work out what is wrong:

```sh
docker logs dnscrypt-server
docker exec dnscrypt-server /opt/unbound/sbin/unbound-checkconf
```

# Deleting everything

In order to delete everything (containers and images), type:

```sh
docker rm --force dnscrypt-server ||:
docker rmi --force jedisct1/dnscrypt-server ||:
```

# Details

- A minimal Ubuntu Linux as a base image.
- Caching resolver: [Unbound](https://www.unbound.net/), with DNSSEC, prefetching,
and no logs. The number of threads and memory usage are automatically adjusted.
Latest stable version, compiled from source. qname minimisation is enabled.
- [encrypted-dns-server](https://github.com/jedisct1/encrypted-dns-server).
Compiled from source.

Keys and certificates are automatically rotated every 8 hour.
