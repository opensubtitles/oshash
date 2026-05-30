# Throwaway builder image for the "exotic" OSHash implementations whose
# toolchains we don't keep on the host. Built on ubuntu:22.04 so the resulting
# binaries are glibc-compatible with the host; we static-link where possible so
# they run after this image is removed. See tools/build_docker_langs.sh.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN sed -i 's/^# deb /deb /' /etc/apt/sources.list && \
    apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        build-essential \
        patchelf \
        libssl-dev \
        curl ca-certificates clang \
        gnat \
        gambc \
        gobjc libobjc-11-dev \
        gnucobol \
        polyml libpolyml-dev \
        gm2 \
        algol68g \
        gforth \
        gnu-smalltalk \
        gprolog \
    && rm -rf /var/lib/apt/lists/* && \
    ln -sf /usr/lib/gcc/x86_64-linux-gnu/10/adalib/libgnat.a \
           /usr/lib/gcc/x86_64-linux-gnu/10/adalib/libgnat-10.a

# Pony (ponyc) — downloaded prebuilt toolchain
RUN curl -sL https://github.com/ponylang/ponyc/releases/latest/download/ponyc-x86-64-unknown-linux-ubuntu22.04.tar.gz \
        | tar xz -C /opt && \
    ln -sf "$(find /opt -name ponyc -type f | head -1)" /usr/local/bin/ponyc

# Odin — downloaded prebuilt toolchain (uses clang to link)
RUN OURL="$(curl -s https://api.github.com/repos/odin-lang/Odin/releases/latest \
        | grep -o 'https://[^"]*linux-amd64[^"]*tar.gz' | head -1)" && \
    curl -sL "$OURL" -o /tmp/odin.tgz && mkdir -p /opt/odin && \
    tar xzf /tmp/odin.tgz -C /opt/odin && rm /tmp/odin.tgz && \
    ln -sf "$(find /opt/odin -name odin -type f | head -1)" /usr/local/bin/odin
