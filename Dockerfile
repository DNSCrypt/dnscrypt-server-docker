FROM jedisct1/alpine-runit:latest
MAINTAINER Frank Denis
ENV SERIAL 1

ENV BUILD_DEPS   make gcc musl-dev git libevent-dev expat-dev shadow autoconf file openssl-dev
ENV RUNTIME_DEPS bash util-linux coreutils findutils grep openssl ldns ldns-tools libevent expat libexecinfo coreutils drill ca-certificates

RUN set -x && \
    apk --update upgrade && apk add --no-cache $RUNTIME_DEPS $BUILD_DEPS && \
    update-ca-certificates 2> /dev/null || true

ENV UNBOUND_GIT_URL https://github.com/jedisct1/unbound.git
ENV UNBOUND_GIT_REVISION 7bd08b7a9987a0780892131f8590b6e384194bbc

RUN set -x && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    git clone "$UNBOUND_GIT_URL" && \
    cd unbound && \
    git checkout "$UNBOUND_GIT_REVISION" && \
    groupadd _unbound && \
    useradd -g _unbound -s /etc -d /dev/null _unbound && \
    ./configure --prefix=/opt/unbound --with-pthreads \
    --with-username=_unbound --with-libevent --enable-event-api && \
    make install && \
    mv /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf.example && \
    rm -fr /opt/unbound/share/man && \
    rm -fr /tmp/* /var/tmp/*

ENV LIBSODIUM_GIT_URL https://github.com/jedisct1/libsodium.git

RUN set -x && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    git clone "$LIBSODIUM_GIT_URL" && \
    cd libsodium && \
    git checkout stable && \
    env CFLAGS=-Ofast ./configure --disable-dependency-tracking && \
    make check && make install && \
    ldconfig /usr/local/lib && \
    rm -fr /tmp/* /var/tmp/*

ENV DNSCRYPT_WRAPPER_GIT_URL https://github.com/jedisct1/dnscrypt-wrapper.git
ENV DNSCRYPT_WRAPPER_GIT_BRANCH xchacha-stamps

COPY queue.h /tmp

RUN set -x && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    git clone --branch=${DNSCRYPT_WRAPPER_GIT_BRANCH} ${DNSCRYPT_WRAPPER_GIT_URL} && \
    cd dnscrypt-wrapper && \
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
    echo apk del --purge $BUILD_DEPS && \
    echo rm -rf /tmp/* /var/tmp/* /usr/local/include

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
