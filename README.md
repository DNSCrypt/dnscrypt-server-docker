[![Travis Status](https://travis-ci.org/DNSCrypt/dnscrypt-server-docker.svg?branch=master)](https://travis-ci.org/DNSCrypt/dnscrypt-server-docker/builds/)
[![DNSCrypt](https://raw.github.com/jedisct1/dnscrypt-server-docker/master/dnscrypt-small.png)](https://dnscrypt.info)

DNSCrypt server Docker image
============================

Run your own caching, non-censoring, non-logging, DNSSEC-capable,
[DNSCrypt](http://dnscrypt.org)-enabled DNS resolver virtually anywhere!

If you are already familiar with Docker, it shouldn't take more than 5 minutes
to get your resolver up and running.

Quickstart
==========

* [How to setup your own DNSCrypt server in less than 10 minutes on Scaleway](https://github.com/jedisct1/dnscrypt-proxy/wiki/How-to-setup-your-own-DNSCrypt-server-in-less-than-10-minutes)
* [DNSCrypt server with vultr.com](https://github.com/jedisct1/dnscrypt-proxy/wiki/DNSCrypt-server-with-vultr.com)

Installation
============

Think about a name. This is going to be part of your DNSCrypt provider name.
If you are planning to make your resolver publicly accessible, this name will
be public.
It has to look like a domain name (`example.com`), but it doesn't have to be
a registered domain.

Let's pick `example.com` here.

Download, create and initialize the container, once and for all:

    $ docker run --name=dnscrypt-server -p 443:443/udp -p 443:443/tcp --net=host \
        jedisct1/dnscrypt-server init -N example.com -E 192.168.1.1:443

This will only accept connections via DNSCrypt on the standard port (443). Replace
`192.168.1.1` with the actual external IP address (not the internal Docker one)
clients will connect to.

`--net=host` provides the best network performance, but may have to be
removed on some shared containers hosting services.

Now, to start the whole stack:

    $ docker start dnscrypt-server

Done.

Note that the actual provider name for DNSCrypt is `2.dnscrypt-cert.example.com`,
not just `example.com` as initially entered. The full name has to start with
`2.dnscrypt-cert.` for the client and the server to use the same version of the
protocol.

Customizing Ports
===================
To customize the default port, pull the repo first:

`git clone https://github.com/DNSCrypt/dnscrypt-server-docker.git`

**Step 1**
Open `dnscrypt-wrapper.sh`
and change: `--listen-address=0.0.0.0:443`
To: `--listen-address=0.0.0.0:your_port_here`

**Step 2**
Open `Dockerfile`
and change: `EXPOSE 443/udp 443/tcp`
To: `EXPOSE your_port_here/udp your_port_here/tcp`

**Step 3**
Open `watchdog.sh`
and change: `drill -p 888 -Q TXT "$provider_name" @127.0.0.1 || \`
To: `drill -p your_port_here -Q TXT "$provider_name" @127.0.0.1 || \`

**Step 4**
Build: `docker build -t dnscrypt-server:yourbuildname .`
(do not forget the . at the end)
You are free to change `yourbuildname` to your liking.

**Step 5**
Run: `sudo docker run -d --name=dnscrypt-server -p yourport:yourport udp -p yourport:yourport/tcp \
    dnscrypt-server:yourbuildname init -N your_server_name -E your_external_ip_here:your_port_here`

replace `yourport` with the custom port you specified earlier.
replace `yourbuildname` if you changed it earlier.
replace `your_server_name` with your server name ie. dnscrypt.info
replace `your_external_ip_here` with your server **external** ip address

** Do not use --net=host with a custom port.

**Step 6**

Run: `docker start dnscrypt-server`

To preserve keys during update see: https://github.com/DNSCrypt/dnscrypt-server-docker/wiki/Update-Docker-image

Customizing Unbound
===================

To add new configuration to Unbound, add files to the `/opt/unbound/etc/unbound/zones`
directory. All files ending in `.conf` will be processed. In this manner, you
can add any directives to the `server:` section of the Unbound configuration.

Serve custom DNS records on a local network
-------------------------------------------
While Unbound is not a full authoritative name server, it supports resolving
custom entries in a way that is serviceable on a small, private LAN. You can use
unbound to resolve private hostnames such as `my-computer.example.com` within
your LAN.

To support such custom entries using this image, first map a volume to the zones
directory. Add this to your `docker run` line:

    -v /myconfig/zones:/opt/unbound/etc/unbound/zones

The whole command to create and initialize a container would look something like
this:

    $ docker run --name=dnscrypt-server \
        -v /myconfig/zones:/opt/unbound/etc/unbound/zones \
        -p 443:443/udp -p 443:443/tcp --net=host \
        jedisct1/dnscrypt-server init -N example.com -E 192.168.1.1:443

Create a new `.conf` file:

    $ touch /myconfig/zones/example.conf

Now, add one or more unbound directives to the file, such as:

    local-zone: "example.com." static
    local-data: "my-computer.example.com. IN A 10.0.0.1"
    local-data: "other-computer.example.com. IN A 10.0.0.2"

Troubleshooting
---------------

If Unbound doesn't like one of the newly added directives, it
will probably not respond over the network. In that case, here are some commands
to work out what is wrong:

    $ docker logs dnscrypt-server
    $ docker exec dnscrypt-server /opt/unbound/sbin/unbound-checkconf

Details
=======

- Alpine Linux as a base image.
- Caching resolver: [Unbound](https://www.unbound.net/), with DNSSEC, prefetching,
and no logs. The number of threads and memory usage are automatically adjusted.
Latest stable version, compiled from source. qname minimisation is enabled.
- [libsodium](https://download.libsodium.org/doc/) - Latest stable version,
minimal build compiled from source.
- [dnscrypt-wrapper](https://github.com/Cofyc/dnscrypt-wrapper) - Latest stable version,
compiled from source.

Keys and certificates are automatically rotated every 12 hour.

Kubernetes
==========

Kubernetes configurations are located in the `kube` directory. Currently these assume
a persistent disk named `dnscrypt-keys` on GCE. You will need to adjust the volumes
definition on other platforms. Once that is setup, you can have a dnscrypt server up
in minutes.

* Create a static IP on GCE. This will be used for the LoadBalancer.
* Edit `kube/dnscrypt-init-job.yml` and change `example.com` to your desired hostname.
* Edit `kube/dnscrypt-srv.yml` and change `loadBalancerIP` to your static IP.
* Run `kubectl create -f kube/dnscrypt-init-job.yml` to setup your keys.
* Run `kubectl create -f kube/dnscrypt-deployment.yml` to deploy the dnscrypt server.
* Run `kubectl create -f kube/dnscrypt-srv.yml` to expose your server to the world.

To get your public key just view the logs for the `dnscrypt-init` job. The public
IP for your server is merely the `dnscrypt` service address.

Coming up next
==============

- Better isolation of the certificate signing process, in a dedicated container.
