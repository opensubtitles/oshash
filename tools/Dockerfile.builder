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
        gnat \
        gambc \
    && rm -rf /var/lib/apt/lists/* && \
    ln -sf /usr/lib/gcc/x86_64-linux-gnu/10/adalib/libgnat.a \
           /usr/lib/gcc/x86_64-linux-gnu/10/adalib/libgnat-10.a
