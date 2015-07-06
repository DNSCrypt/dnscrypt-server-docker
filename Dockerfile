FROM caleblloyd/phusion-baseimage-docker-15.04
MAINTAINER Frank Denis
ENV SERIAL 1

ENV BUILD_DEPS autoconf gcc libc-dev make pkg-config git

RUN set -x && \
    apt-get update && apt-get install -y \
        $BUILD_DEPS \
        bsdmainutils \
        ldnsutils \
        --no-install-recommends

ENV LIBRESSL_VERSION 2.2.0
ENV LIBRESSL_SHA256 9690d8f38a5d48425395452eeb305b05bb0f560cd96e0ee30f370d4f16563040
ENV LIBRESSL_DOWNLOAD_URL http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz

RUN set -x && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    curl -sSL $LIBRESSL_DOWNLOAD_URL -o libressl.tar.gz && \
    echo "${LIBRESSL_SHA256} *libressl.tar.gz" | sha256sum -c - && \
    tar xzf libressl.tar.gz && \
    rm -f libressl.tar.gz && \
    cd libressl-${LIBRESSL_VERSION} && \
    ./configure --disable-dependency-tracking --prefix=/opt/libressl && \
    make check && make install && \
    rm -fr /opt/libressl/share/man && \
    echo /opt/libressl/lib > /etc/ld.so.conf.d/libressl.conf && ldconfig && \
    rm -fr /tmp/*

ENV UNBOUND_VERSION 1.5.3
ENV UNBOUND_SHA256 76bdc875ed4d1d3f8e4cfe960e6df78ee5c6c7c18abac11331cf93a7ae129eca
ENV UNBOUND_DOWNLOAD_URL http://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz

RUN set -x && \
    apt-get update && \
    apt-get install -y \
        libevent-2.0 \
        libevent-dev \
        libexpat1 \
        libexpat1-dev \
        --no-install-recommends && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    curl -sSL $UNBOUND_DOWNLOAD_URL -o unbound.tar.gz && \
    echo "${UNBOUND_SHA256} *unbound.tar.gz" | sha256sum -c - && \
    tar xzf unbound.tar.gz && \
    rm -f unbound.tar.gz && \
    cd unbound-${UNBOUND_VERSION} && \
    groupadd _unbound && \
    useradd -g _unbound -s /etc -d /dev/null _unbound && \
    ./configure --disable-dependency-tracking --prefix=/opt/unbound --with-pthreads \
        --with-username=_unbound --with-ssl=/opt/libressl --with-libevent \
        --enable-event-api && \
    make install && \
    mv /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf.example && \
    rm -fr /opt/unbound/share/man && \
    apt-get purge -y --auto-remove \
        libexpat-dev \
        libevent-dev && \
    apt-get autoremove -y && apt-get clean && \
    rm -fr /tmp/* /var/tmp/*

ENV LIBSODIUM_VERSION 1.0.3
ENV LIBSODIUM_SHA256 cbcfc63cc90c05d18a20f229a62c7e7054a73731d0aa858c0517152c549b1288
ENV LIBSODIUM_DOWNLOAD_URL https://download.libsodium.org/libsodium/releases/libsodium-${LIBSODIUM_VERSION}.tar.gz

RUN set -x && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    curl -sSL $LIBSODIUM_DOWNLOAD_URL -o libsodium.tar.gz && \
    echo "${LIBSODIUM_SHA256} *libsodium.tar.gz" | sha256sum -c - && \
    tar xzf libsodium.tar.gz && \
    rm -f libsodium.tar.gz && \
    cd libsodium-${LIBSODIUM_VERSION} && \
    ./configure --disable-dependency-tracking --enable-minimal --prefix=/opt/libsodium && \
    make check && make install && \
    echo /opt/libsodium/lib > /etc/ld.so.conf.d/libsodium.conf && ldconfig && \
    rm -fr /tmp/*

ENV DNSCRYPT_PROXY_VERSION 1.5.0
ENV DNSCRYPT_PROXY_SHA256 b78c52efca2e6b26c68638493c1aa7733b41106363a8f2a3bec3b8da44aafcbb
ENV DNSCRYPT_PROXY_DOWNLOAD_URL http://download.dnscrypt.org/dnscrypt-proxy/dnscrypt-proxy-${DNSCRYPT_PROXY_VERSION}.tar.gz

RUN set -x && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    curl -sSL $DNSCRYPT_PROXY_DOWNLOAD_URL -o dnscrypt-proxy.tar.gz && \
    echo "${DNSCRYPT_PROXY_SHA256} *dnscrypt-proxy.tar.gz" | sha256sum -c - && \
    tar xvf dnscrypt-proxy.tar.gz && \
    rm -f dnscrypt-proxy.tar.gz && \
    cd dnscrypt-proxy-${DNSCRYPT_PROXY_VERSION} && \
    mkdir -p /opt/dnscrypt-proxy/empty && \
    groupadd _dnscrypt-proxy && \
    useradd -g _dnscrypt-proxy -s /etc -d /opt/dnscrypt-proxy/empty _dnscrypt-proxy && \
    env CPPFLAGS=-I/opt/libsodium/include LDFLAGS=-L/opt/libsodium/lib \
        ./configure --disable-dependency-tracking --prefix=/opt/dnscrypt-proxy && \
    make install && \
    rm -fr /opt/dnscrypt-proxy/share && \
    rm -fr /tmp/* /var/tmp/*

ENV DNSCRYPT_WRAPPER_GIT_TAG stable
ENV DNSCRYPT_WRAPPER_SERIAL 1.0.17.0
ENV DNSCRYPT_WRAPPER_GIT_REMOTE_URL https://github.com/jedisct1/dnscrypt-wrapper.git

RUN set -x && \
    apt-get update && \
    apt-get install -y \
        libevent-2.0 \
        libevent-dev \
        --no-install-recommends && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    git clone "$DNSCRYPT_WRAPPER_GIT_REMOTE_URL" dnscrypt-wrapper && \
    cd dnscrypt-wrapper && \
    git checkout "$DNSCRYPT_WRAPPER_GIT_TAG" && \
    mkdir -p /opt/dnscrypt-wrapper/empty && \
    groupadd _dnscrypt-wrapper && \
    useradd -g _dnscrypt-wrapper -s /etc -d /opt/dnscrypt-wrapper/empty _dnscrypt-wrapper && \
    groupadd _dnscrypt-signer && \
    useradd -g _dnscrypt-signer -G _dnscrypt-wrapper -s /etc -d /dev/null _dnscrypt-signer && \
    make configure && \
    ./configure --prefix=/opt/dnscrypt-wrapper --with-sodium=/opt/libsodium && \
    make install && \
    apt-get purge -y --auto-remove libevent-dev && \
    apt-get autoremove -y && apt-get clean && \
    rm -fr /tmp/* /var/tmp/*

RUN set -x && \
    apt-get purge -y --auto-remove $BUILD_DEPS && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p \
    /etc/service/unbound \
    /etc/service/watchdog

ADD entrypoint.sh /

ADD unbound.sh /etc/service/unbound/run
ADD unbound-check.sh /etc/service/unbound/check

ADD dnscrypt-wrapper.sh /etc/service/dnscrypt-wrapper/run

ADD key-rotation.sh /etc/service/key-rotation/run
ADD watchdog.sh /etc/service/watchdog/run

VOLUME ["/opt/dnscrypt-wrapper/etc/keys"]

EXPOSE 53/udp 53/tcp 443/udp 443/tcp

CMD ["start"]

ENTRYPOINT ["/entrypoint.sh"]
