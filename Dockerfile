FROM jedisct1/alpine-runit:latest
MAINTAINER Frank Denis
ENV SERIAL 3

ENV BUILD_DEPS   make gcc musl-dev git libevent-dev expat-dev shadow autoconf file openssl-dev byacc linux-headers
ENV RUNTIME_DEPS bash util-linux coreutils findutils grep openssl ldns ldns-tools libevent expat libexecinfo coreutils drill ca-certificates

RUN set -x && \
    apk --no-cache upgrade && apk add --no-cache $RUNTIME_DEPS && \
    update-ca-certificates 2> /dev/null || true

ENV UNBOUND_GIT_URL https://github.com/jedisct1/unbound.git
ENV UNBOUND_GIT_REVISION f5e3a85e960c2574be87f75a2b2c894d6995e0e2

RUN set -x && \
    apk add --no-cache $BUILD_DEPS && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    git clone --depth=1000 "$UNBOUND_GIT_URL" && \
    cd unbound && \
    git checkout "$UNBOUND_GIT_REVISION" && \
    groupadd _unbound && \
    useradd -g _unbound -s /etc -d /dev/null _unbound && \
    ./configure --prefix=/opt/unbound --with-pthreads \
    --with-username=_unbound --with-libevent --enable-event-api && \
    make -j$(getconf _NPROCESSORS_ONLN) install && \
    mv /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf.example && \
    apk del --purge $BUILD_DEPS && \
    rm -fr /opt/unbound/share/man && \
    rm -fr /tmp/* /var/tmp/*

ENV LIBSODIUM_GIT_URL https://github.com/jedisct1/libsodium.git

RUN set -x && \
    apk add --no-cache $BUILD_DEPS && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    git clone --depth=1 --branch stable "$LIBSODIUM_GIT_URL" && \
    cd libsodium && \
    env CFLAGS=-Ofast ./configure --disable-dependency-tracking && \
    make -j$(getconf _NPROCESSORS_ONLN) check && make -j$(getconf _NPROCESSORS_ONLN) install && \
    ldconfig /usr/local/lib && \
    apk del --purge $BUILD_DEPS && \
    rm -fr /tmp/* /var/tmp/*

ENV DNSCRYPT_WRAPPER_GIT_URL https://github.com/jedisct1/dnscrypt-wrapper.git
ENV DNSCRYPT_WRAPPER_GIT_BRANCH xchacha-stamps

COPY queue.h /tmp

RUN set -x && \
    apk add --no-cache $BUILD_DEPS && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    git clone --depth=1 --branch=${DNSCRYPT_WRAPPER_GIT_BRANCH} ${DNSCRYPT_WRAPPER_GIT_URL} && \
    cd dnscrypt-wrapper && \
    sed -i 's#<sys/queue.h>#"/tmp/queue.h"#' compat.h && \
    sed -i 's#HAVE_BACKTRACE#NO_BACKTRACE#' compat.h && \
    mkdir -p /opt/dnscrypt-wrapper/empty && \
    groupadd _dnscrypt-wrapper && \
    useradd -g _dnscrypt-wrapper -s /etc -d /opt/dnscrypt-wrapper/empty _dnscrypt-wrapper && \
    groupadd _dnscrypt-signer && \
    useradd -g _dnscrypt-signer -G _dnscrypt-wrapper -s /etc -d /dev/null _dnscrypt-signer && \
    make -j$(getconf _NPROCESSORS_ONLN) configure && \
    env CFLAGS=-Ofast ./configure --prefix=/opt/dnscrypt-wrapper && \
    make -j$(getconf _NPROCESSORS_ONLN) install && \
    apk del --purge $BUILD_DEPS && \
    rm -fr /tmp/* /var/tmp/*

RUN set -x && \
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
