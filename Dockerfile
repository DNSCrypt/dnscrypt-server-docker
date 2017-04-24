FROM jedisct1/alpine-runit:latest
MAINTAINER Frank Denis
ENV SERIAL 1

ENV BUILD_DEPS   make gcc musl-dev git ldns-dev libevent-dev expat-dev shadow autoconf file libexecinfo-dev
ENV RUNTIME_DEPS libressl ldns ldns-tools libevent expat libtool libexecinfo coreutils drill

RUN set -x && \
    apk --update upgrade && apk add $RUNTIME_DEPS $BUILD_DEPS

ENV UNBOUND_VERSION 1.6.2
ENV UNBOUND_SHA256 1a323d72c32180b7141c9e6ebf199fc68a0208dfebad4640cd2c4c27235e3b9c
ENV UNBOUND_DOWNLOAD_URL https://www.unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz

RUN set -x && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    wget -O unbound.tar.gz $UNBOUND_DOWNLOAD_URL && \
    echo "${UNBOUND_SHA256} *unbound.tar.gz" | sha256sum -c - && \
    tar xzf unbound.tar.gz && \
    rm -f unbound.tar.gz && \
    cd unbound-${UNBOUND_VERSION} && \
    groupadd _unbound && \
    useradd -g _unbound -s /etc -d /dev/null _unbound && \
    ./configure --prefix=/opt/unbound --with-pthreads \
        --with-username=_unbound --with-libevent --enable-event-api && \
    make install && \
    mv /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf.example && \
    rm -fr /opt/unbound/share/man && \
    rm -fr /tmp/* /var/tmp/*

ENV LIBSODIUM_VERSION 1.0.12
ENV LIBSODIUM_SHA256 b8648f1bb3a54b0251cf4ffa4f0d76ded13977d4fa7517d988f4c902dd8e2f95
ENV LIBSODIUM_DOWNLOAD_URL https://download.libsodium.org/libsodium/releases/libsodium-${LIBSODIUM_VERSION}.tar.gz

RUN set -x && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    wget -O libsodium.tar.gz $LIBSODIUM_DOWNLOAD_URL && \
    echo "${LIBSODIUM_SHA256} *libsodium.tar.gz" | sha256sum -c - && \
    tar xzf libsodium.tar.gz && \
    rm -f libsodium.tar.gz && \
    cd libsodium-${LIBSODIUM_VERSION} && \
    env CFLAGS=-Ofast ./configure --disable-dependency-tracking && \
    make check && make install && \
    ldconfig /usr/local/lib && \
    rm -fr /tmp/* /var/tmp/*

ENV DNSCRYPT_PROXY_VERSION 1.9.4
ENV DNSCRYPT_PROXY_SHA256 40543efbcd56033ac03a1edf4581305e8c9bed4579ac55e6279644f07c315307
ENV DNSCRYPT_PROXY_DOWNLOAD_URL https://download.dnscrypt.org/dnscrypt-proxy/dnscrypt-proxy-${DNSCRYPT_PROXY_VERSION}.tar.gz

RUN set -x && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    wget -O dnscrypt-proxy.tar.gz $DNSCRYPT_PROXY_DOWNLOAD_URL && \
    echo "${DNSCRYPT_PROXY_SHA256} *dnscrypt-proxy.tar.gz" | sha256sum -c - && \
    tar xzf dnscrypt-proxy.tar.gz && \
    rm -f dnscrypt-proxy.tar.gz && \
    cd dnscrypt-proxy-${DNSCRYPT_PROXY_VERSION} && \
    mkdir -p /opt/dnscrypt-proxy/empty && \
    groupadd _dnscrypt-proxy && \
    useradd -g _dnscrypt-proxy -s /etc -d /opt/dnscrypt-proxy/empty _dnscrypt-proxy && \
    env CFLAGS=-Os ./configure --disable-dependency-tracking --prefix=/opt/dnscrypt-proxy --disable-plugins && \
    make install && \
    rm -fr /opt/dnscrypt-proxy/share && \
    rm -fr /tmp/* /var/tmp/*

ENV DNSCRYPT_WRAPPER_VERSION 0.2.2
ENV DNSCRYPT_WRAPPER_SHA256 6fa0d2bea41a11c551d6b940bf4dffeaaa0e034fffd8c67828ee2093c1230fee
ENV DNSCRYPT_WRAPPER_DOWNLOAD_URL https://github.com/Cofyc/dnscrypt-wrapper/releases/download/v${DNSCRYPT_WRAPPER_VERSION}/dnscrypt-wrapper-v${DNSCRYPT_WRAPPER_VERSION}.tar.bz2

COPY queue.h /tmp

RUN set -x && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    wget -O dnscrypt-wrapper.tar.bz2 $DNSCRYPT_WRAPPER_DOWNLOAD_URL && \
    echo "${DNSCRYPT_WRAPPER_SHA256} *dnscrypt-wrapper.tar.bz2" | sha256sum -c - && \
    tar xjf dnscrypt-wrapper.tar.bz2 && \
    cd dnscrypt-wrapper-v${DNSCRYPT_WRAPPER_VERSION} && \
    sed -i 's#<sys/queue.h>#"/tmp/queue.h"#' compat.h && \
    sed -i 's#HAVE_BACKTRACE#NO_BACKTRACE#' compat.h && \
    mkdir -p /opt/dnscrypt-wrapper/empty && \
    groupadd _dnscrypt-wrapper && \
    useradd -g _dnscrypt-wrapper -s /etc -d /opt/dnscrypt-wrapper/empty _dnscrypt-wrapper && \
    groupadd _dnscrypt-signer && \
    useradd -g _dnscrypt-signer -G _dnscrypt-wrapper -s /etc -d /dev/null _dnscrypt-signer && \
    make configure && \
    env CFLAGS=-Ofast ./configure --prefix=/opt/dnscrypt-wrapper && \
    make install && \
    rm -fr /tmp/* /var/tmp/*

RUN set -x && \
    apk del --purge $BUILD_DEPS && \
    rm -rf /tmp/* /var/tmp/* /usr/local/include

RUN mkdir -p \
    /etc/service/unbound \
    /etc/service/watchdog

COPY entrypoint.sh /

COPY unbound.sh /etc/service/unbound/run
COPY unbound-check.sh /etc/service/unbound/check

COPY dnscrypt-wrapper.sh /etc/service/dnscrypt-wrapper/run

COPY key-rotation.sh /etc/service/key-rotation/run
COPY watchdog.sh /etc/service/watchdog/run

VOLUME ["/opt/dnscrypt-wrapper/etc/keys"]

EXPOSE 443/udp 443/tcp

CMD ["/sbin/start_runit"]

ENTRYPOINT ["/entrypoint.sh"]
