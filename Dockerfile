FROM jedisct1/alpine-runit:latest
LABEL maintainer="Frank Denis"
SHELL ["/bin/sh", "-x", "-c"]
ENV SERIAL 3

ENV CFLAGS=-Ofast
ENV BUILD_DEPS   curl make gcc musl-dev git libevent-dev expat-dev shadow autoconf file openssl-dev byacc linux-headers
ENV RUNTIME_DEPS bash util-linux coreutils findutils grep openssl ldns ldns-tools libevent expat libexecinfo coreutils drill ca-certificates

RUN apk --no-cache upgrade && apk add --no-cache $RUNTIME_DEPS
RUN update-ca-certificates 2> /dev/null || true

ENV UNBOUND_GIT_URL https://github.com/jedisct1/unbound.git
ENV UNBOUND_GIT_REVISION 35ac577d99d56869f2f87dcc7b5e36b8996df5ca

WORKDIR /tmp

RUN apk add --no-cache $BUILD_DEPS && \
    git clone --depth=1000 "$UNBOUND_GIT_URL" && \
    cd unbound && \
    git checkout "$UNBOUND_GIT_REVISION" && \
    groupadd _unbound && \
    useradd -g _unbound -s /etc -d /dev/null _unbound && \
    ./configure --prefix=/opt/unbound --with-pthreads \
    --with-username=_unbound --with-libevent --enable-event-api && \
    make -j"$(getconf _NPROCESSORS_ONLN)" install && \
    mv /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf.example && \
    apk del --purge $BUILD_DEPS && \
    rm -fr /opt/unbound/share/man && \
    rm -fr /tmp/* /var/tmp/*

ENV RUSTFLAGS "-C target-feature=-crt-static -C link-arg=-s"

RUN apk add --no-cache $BUILD_DEPS && \
    curl -sSf https://sh.rustup.rs | bash -s -- -y --default-toolchain nightly

RUN source $HOME/.cargo/env && \
    cargo install encrypted-dns && \
    mkdir -p /opt/encrypted-dns/sbin && \
    mkdir -p /opt/encrypted-dns/etc/keys && \
    mv ~/.cargo/bin/encrypted-dns /opt/encrypted-dns/sbin/ && \
    strip --strip-all /opt/encrypted-dns/sbin/encrypted-dns && \
    groupadd _encrypted-dns && \
    useradd -g _encrypted-dns -s /etc -d /opt/encrypted-dns/empty _encrypted-dns && \
    chown _encrypted-dns:_encrypted-dns /opt/encrypted-dns/etc/keys && \
    chmod 700 /opt/encrypted-dns/etc/keys && \
    apk del --purge $BUILD_DEPS && \
    rm -fr ~/.cargo ~/.rustup && \
    rm -fr /tmp/* /var/tmp/*

RUN mkdir -p \
    /etc/service/unbound \
    /etc/service/watchdog

COPY encrypted-dns.toml.in /opt/encrypted-dns/etc/

COPY entrypoint.sh /

COPY unbound.sh /etc/service/unbound/run
COPY unbound-check.sh /etc/service/unbound/check

COPY encrypted-dns.sh /etc/service/encrypted-dns/run

COPY watchdog.sh /etc/service/watchdog/run

VOLUME ["/opt/encrypted-dns/etc/keys"]

EXPOSE 443/udp 443/tcp

CMD ["/sbin/start_runit"]

ENTRYPOINT ["/entrypoint.sh"]
