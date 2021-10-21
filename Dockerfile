# global args
ARG __BUILD_DIR__="/build"
ARG __DATA_DIR__="/data"
ARG MEMCACHED_VERSION="1.6.12"



FROM fscm/centos:stream as build

ARG __BUILD_DIR__
ARG __DATA_DIR__
ARG __WORK_DIR__="/work"
ARG MEMCACHED_VERSION
ARG __USER__="root"
ARG __SOURCE_DIR__="${__WORK_DIR__}/src"

ENV \
  LANG="C.UTF-8" \
  LC_ALL="C.UTF-8"

USER "${__USER__}"

COPY "LICENSE" "files/" "${__WORK_DIR__}"/

WORKDIR "${__WORK_DIR__}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN \
# build env
    echo '--> setting build env' && \
    set +h && \
    export __NPROC__="$(getconf _NPROCESSORS_ONLN || echo 1)" && \
    export DCACHE_LINESIZE="$(getconf LEVEL1_DCACHE_LINESIZE || echo 64)" && \
    export MAKEFLAGS="--silent --no-print-directory --jobs ${__NPROC__}" && \
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig && \
# build structure
    echo '--> creating build structure' && \
    for folder in 'bin'; do \
        install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/usr/${folder}"; \
    done && \
    for folder in '/tmp' "${__DATA_DIR__}"; do \
        install --directory --owner="${__USER__}" --group="${__USER__}" --mode=1777 "${__BUILD_DIR__}${folder}"; \
    done && \
# dependencies
    echo '--> instaling dependencies' && \
    dnf --quiet --enablerepo='powertools' makecache --refresh && \
    dnf --assumeyes --quiet --setopt=install_weak_deps='no' install \
        binutils \
        ca-certificates \
        curl \
        diffutils \
        file \
        findutils \
        gcc \
        gzip \
        jq \
        make \
        patch \
        perl-interpreter \
        python3-devel \
        rsync \
        tar \
        xz \
        > /dev/null && \
    dnf --assumeyes --quiet --setopt=install_weak_deps='no' --enablerepo='powertools' install \
        gperf \
        > /dev/null && \
# kernel headers
    echo '--> installing kernel headers' && \
    KERNEL_VERSION="$(curl --silent --location --retry 3 'https://www.kernel.org/releases.json' | jq -r '.latest_stable.version')" && \
    install --directory "${__SOURCE_DIR__}/kernel" && \
    curl --silent --location --retry 3 "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-${KERNEL_VERSION}.tar.xz" \
        | tar xJ --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/kernel" $(echo linux-*/{Makefile,arch,include,scripts,tools,usr}) && \
    cd "${__SOURCE_DIR__}/kernel" && \
    make INSTALL_HDR_PATH="/usr/local" headers_install > /dev/null && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/kernel" && \
# musl
    echo '--> installing musl libc' && \
    install --directory "${__SOURCE_DIR__}/musl/_build" && \
    curl --silent --location --retry 3 "https://musl.libc.org/releases/musl-latest.tar.gz" \
        | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/musl" && \
    cd "${__SOURCE_DIR__}/musl/_build" && \
    ../configure \
        CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
        --prefix='/usr/local' \
        --disable-debug \
        --disable-shared \
        --enable-wrapper=all \
        --enable-static \
        > /dev/null && \
    make > /dev/null && \
    make install > /dev/null && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/musl" && \
# zlib
    echo '--> installing zlib' && \
    ZLIB_VERSION="$(rpm -q --qf "%{VERSION}" zlib)" && \
    install --directory "${__SOURCE_DIR__}/zlib/_build" && \
    curl --silent --location --retry 3 "https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz" \
        | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/zlib" && \
    cd "${__SOURCE_DIR__}/zlib/_build" && \
    sed -i.orig -e '/(man3dir)/d' ../Makefile.in && \
    CC="musl-gcc -static --static" \
    CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
    ../configure \
        --prefix='/usr/local' \
        --includedir='/usr/local/include' \
        --libdir='/usr/local/lib' \
        --static \
        > /dev/null && \
    make > /dev/null && \
    make install > /dev/null && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/zlib" && \
# openssl
    echo '--> installing openssl' && \
    OPENSSL_VERSION="$(rpm -q --qf "%{VERSION}" openssl-libs)" && \
    install --directory "${__SOURCE_DIR__}/openssl/_build" && \
    curl --silent --location --retry 3 "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" \
        | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/openssl" && \
    cd "${__SOURCE_DIR__}/openssl/_build" && \
    ../config \
        CC="musl-gcc -static --static" \
        --openssldir='/etc/ssl' \
        --prefix='/usr/local' \
        --libdir='/usr/local/lib' \
        --release \
        --static \
        enable-cms \
        enable-ec_nistp_64_gcc_128 \
        enable-rfc3779 \
        no-comp \
        no-shared \
        no-ssl3 \
        no-weak-ssl-ciphers \
        zlib \
        -pipe \
        -static \
        -DCLS=${DCACHE_LINESIZE} \
        -DNDEBUG \
        -DOPENSSL_NO_HEARTBEATS \
        -O2 -g0 -s -w -pipe -m64 -mtune=generic '-DDEVRANDOM="\"/dev/urandom\""' && \
    make > /dev/null && \
    make install_sw > /dev/null && \
    make install_ssldirs > /dev/null && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/openssl" && \
# libevent
    echo '--> installing libevent' && \
    LIBEVENT_URL="$(curl --silent --location --retry 3 'https://api.github.com/repos/libevent/libevent/releases/latest' | jq -r '.assets[] | select(.content_type=="application/gzip") | .browser_download_url')" && \
    install --directory "${__SOURCE_DIR__}/libevent/_build" && \
    curl --silent --location --retry 3 "${LIBEVENT_URL}" \
        | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libevent" && \
    cd "${__SOURCE_DIR__}/libevent/_build" && \
    ../configure \
        CC="musl-gcc -static --static" \
        CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
        --quiet \
        --prefix='/usr/local' \
        --includedir='/usr/local/include' \
        --libdir='/usr/local/lib' \
        --sysconfdir='/etc' \
        --enable-fast-install \
        --enable-silent-rules \
        --enable-static \
        --disable-debug-mode \
        --disable-doxygen-html \
        --disable-samples \
        --disable-shared && \
    make > /dev/null && \
    make install > /dev/null && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/libevent" && \
# libseccomp
    echo '--> installing libseccomp' && \
    LIBSECCOMP_URL="$(curl --silent --location --retry 3 'https://api.github.com/repos/seccomp/libseccomp/releases/latest' | jq -r '.assets[] | select(.content_type=="application/gzip") | .browser_download_url')" && \
    install --directory "${__SOURCE_DIR__}/libseccomp/_build" && \
    curl --silent --location --retry 3 "${LIBSECCOMP_URL}" \
        | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libseccomp" && \
    cd "${__SOURCE_DIR__}/libseccomp/_build" && \
    sed -i.orig -e '/^SUBDIRS/ s/ \(doc\|tests\)//g' ../Makefile.in && \
    ../configure \
        CC="musl-gcc -static --static" \
        CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
        --quiet \
        --prefix='/usr/local' \
        --includedir='/usr/local/include' \
        --libdir='/usr/local/lib' \
        --sysconfdir='/etc' \
        --enable-fast-install \
        --enable-silent-rules \
        --enable-static \
        --disable-python \
        --disable-shared && \
    make > /dev/null && \
    make install > /dev/null && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/libseccomp" && \
# cyrus-sasl
    # echo '--> installing cyrus-sasl' && \
    # CYRUS_SASL_URL="$(curl --silent --location --retry 3 'https://api.github.com/repos/cyrusimap/cyrus-sasl/releases/latest' | jq -r '.assets[] | select(.content_type=="application/x-gzip") | .browser_download_url')" && \
    # install --directory "${__SOURCE_DIR__}/cyrus-sasl/_build" && \
    # curl --silent --location --retry 3 "${CYRUS_SASL_URL}" \
    #     | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/cyrus-sasl" && \
    # cd "${__SOURCE_DIR__}/cyrus-sasl/_build" && \
    # ../configure \
    #     CC="musl-gcc -static --static" \
    #     CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
    #     --quiet \
    #     --prefix='/usr/local' \
    #     --includedir='/usr/local/include' \
    #     --libdir='/usr/local/lib' \
    #     --sysconfdir='/etc' \
    #     --with-lib-subdir='lib' \
    #     --with-openssl='/usr/local' \
    #     --with-devrandom='/dev/urandom' \
    #     --with-rc4 \
    #     --without-pwcheck \
    #     --without-sqlite \
    #     --enable-fast-install \
    #     --enable-silent-rules \
    #     --enable-static \
    #     --enable-staticdlopen \
    #     --disable-java \
    #     --disable-otp \
    #     --enable-anon \
    #     --enable-cram \
    #     --enable-digest \
    #     --enable-ntlm \
    #     --enable-plain \
    #     --enable-login \
    #     --enable-auth-sasldb \
    #     --enable-alwaystrue \
    #     --disable-shared && \
    # make --directory='./common' > /dev/null && \
    # make --directory='./plugins' > /dev/null && \
    # make > /dev/null && \
    # make dist_man3_MANS='' install > /dev/null && \
    # cd ~- && \
    # rm -rf "${__SOURCE_DIR__}/cyrus-sasl" && \
# memcached
    echo '--> installing memcached' && \
    install --directory "${__SOURCE_DIR__}/memcached/_build" && \
    curl --silent --location --retry 3 "http://www.memcached.org/files/memcached-${MEMCACHED_VERSION}.tar.gz" \
        | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/memcached" && \
    for p in "${__WORK_DIR__}/patches/memcached-${MEMCACHED_VERSION//./_}"*.patch; do \
        patch --quiet --backup --unified --strip=0 --directory="${__SOURCE_DIR__}/memcached" < ${p}; \
    done && \
    cd "${__SOURCE_DIR__}/memcached/_build" && \
    ../configure \
        CC="musl-gcc -static --static" \
        CFLAGS="-O2 -g0 -s -w -pipe -mtune=generic -DNDEBUG -DCLS=${DCACHE_LINESIZE}" \
        --quiet \
        --prefix='/usr' \
        --includedir='/usr/include' \
        --libdir='/usr/lib' \
        --sysconfdir='/etc' \
        # --enable-sasl \
        # --enable-sasl-pwdb \
        --enable-seccomp \
        --enable-silent-rules \
        --enable-static \
        --enable-tls \
        --disable-docs && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install-exec > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/memcached" && \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/licenses/memcached" '../COPYING' && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/memcached" && \
# stripping
    echo '--> stripping binaries' && \
    find "${__BUILD_DIR__}"/usr/bin -type f -not -links +1 -exec strip --strip-all {} ';' && \
# licenses
    echo '--> project licenses' && \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/licenses" "${__WORK_DIR__}/LICENSE" && \
# done
    echo '--> all done!'



FROM scratch

ARG __BUILD_DIR__
ARG __DATA_DIR__
ARG REDIS_VERSION

LABEL \
    maintainer="Frederico Martins <https://hub.docker.com/u/fscm/>" \
    vendor="fscm" \
    cmd="docker container run --detach --publish 11211:11211/tcp fscm/memcached" \
    params="--volume $$PWD:${__DATA_DIR__}:rw"
LABEL \
    org.label-schema.schema-version="1.0" \
    org.label-schema.name="fscm/memcached" \
    org.label-schema.description="A small image that can be used to run the memcached server" \
    org.label-schema.url="https://memcached.org/" \
    org.label-schema.vcs-url="https://github.com/fscm/docker-memcached/" \
    org.label-schema.vendor="fscm" \
    org.label-schema.version=${REDIS_VERSION} \
    org.label-schema.docker.cmd="docker container run --interactive --rm --tty --publish 11211:11211/tcp fscm/memcached" \
    org.label-schema.docker.cmd.test="docker container run --interactive --rm --tty fscm/memcached --version" \
    org.label-schema.docker.params="--volume $$PWD:${__DATA_DIR__}:rw"

EXPOSE 11211/tcp

COPY --from=build "${__BUILD_DIR__}" "/"

VOLUME ["${__DATA_DIR__}"]

WORKDIR "${__DATA_DIR__}"

ENTRYPOINT ["/usr/bin/memcached"]

#CMD ["--help"]
