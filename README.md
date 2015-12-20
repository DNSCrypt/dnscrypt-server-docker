[![DNSCrypt](https://raw.github.com/jedisct1/dnscrypt-server-docker/master/dnscrypt-small.png)](https://dnscrypt.org)

DNSCrypt server Docker image
============================

Run your own caching, non-censoring, non-logging, DNSSEC-capable,
[DNSCrypt](http://dnscrypt.org)-enabled DNS resolver virtually anywhere!

If you are already familiar with Docker, it shouldn't take more than 5 minutes
to get your resolver up and running.

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
        jedisct1/unbound-dnscrypt-server init -N example.com

This will only accept connections via DNSCrypt on the standard port (443).

`--net=host` provides the best network performance, but may have to be
removed on some shared containers hosting services.

Now, to start the whole stack:

    $ docker start dnscrypt-server

Done.

To check that your DNSCrypt-enabled DNS resolver is accessible, run the
DNSCrypt client proxy on another host:

    # dnscrypt-proxy \
        --provider-key=<provider key, as displayed when the container was initialized> \
        --resolver-address=<dnscrypt resolver public IP address> \
        --provider-name=2.dnscrypt-cert.example.com

And try using `127.0.0.1` as a DNS resolver.

Note that the actual provider name for DNSCrypt is `2.dnscrypt-cert.example.com`,
not just `example.com` as initially entered. The full name has to start with
`2.dnscrypt-cert.` for the client and the server to use the same version of the
protocol.

Let the world know about your server
====================================

Is your brand new DNS resolver publicly accessible?

Fork the [dnscrypt-proxy repository](https://github.com/jedisct1/dnscrypt-proxy),
edit the [dnscrypt.csv](https://github.com/jedisct1/dnscrypt-proxy/blob/master/dnscrypt-resolvers.csv)
file to add your resolver's informations, and submit a pull request to have it
included in the list of public DNSCrypt resolvers!

Details
=======

- Caching resolver: [Unbound](https://www.unbound.net/), with DNSSEC, prefetching,
and no logs. The number of threads and memory usage are automatically adjusted.
Latest stable version, compiled from source. qname minimisation is enabled.
- [LibreSSL](http://www.libressl.org/) - Latest stable version, compiled from source.
- [libsodium](https://download.libsodium.org/doc/) - Latest stable version,
minimal build compiled from source.
- [dnscrypt-wrapper](https://github.com/Cofyc/dnscrypt-wrapper) - Latest stable version,
compiled from source.
- [dnscrypt-proxy](https://github.com/jedisct1/dnscrypt-proxy) - Latest stable version,
compiled from source.

Keys and certificates are automatically rotated every 12 hour.

Coming up next
==============

- Namecoin support, by linking a distinct image with namecore and ncdns.
- Better isolation of the certificate signing process, in a dedicated container.
