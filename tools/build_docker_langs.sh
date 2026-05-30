#!/bin/bash
# Build the OSHash implementations whose toolchains we don't keep on the host.
#
# Each is compiled inside the throwaway `oshash-builder` image (Ubuntu 22.04, so
# the binaries are glibc-compatible with the host). Runtimes are either
# statically linked (Ada, Objective-C) or bundled beside the binary with an
# $ORIGIN rpath (Scheme/Gambit, Standard ML/Poly/ML, COBOL/GnuCOBOL), so each
# binary runs on the host with no toolchain installed. test_all.sh then runs
# these like any other compiled implementation. Pass --rmi to delete the builder
# image afterwards and reclaim disk (the binaries persist).
set -e

REPO="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="oshash-builder"
RMI=0
[ "$1" = "--rmi" ] && RMI=1

if ! command -v docker >/dev/null 2>&1; then
    echo "docker not available — cannot build the Docker-only languages." >&2
    exit 1
fi

echo "Building $IMAGE image..."
docker build -q -f "$REPO/tools/Dockerfile.builder" -t "$IMAGE" "$REPO" >/dev/null

echo "Compiling implementations inside the container..."
docker run --rm -v "$REPO:/repo" -w /repo "$IMAGE" bash -c '
set -e

# Copy a binary every shared lib it needs that is NOT part of the base system,
# then point its rpath at its own directory so it runs on the host as-is.
bundle_libs() {
    local bin="$1" dir lib
    dir="$(dirname "$bin")"
    ldd "$bin" | awk "/=> \// {print \$3}" | while read -r lib; do
        case "$lib" in
            */libc.so*|*/libm.so*|*/libpthread.so*|*/libdl.so*|*/librt.so*|*/ld-linux*) ;;
            *) cp -f "$lib" "$dir/" ;;
        esac
    done
    patchelf --set-rpath "\$ORIGIN" "$bin"
}

# Ada — fully static
cd /repo/implementations/ada
gnatmake -q oshash.adb -o oshash -largs -static
strip oshash 2>/dev/null || true

# Objective-C — fully static (GNU runtime, no Foundation)
cd /repo/implementations/objc
gcc -std=gnu11 -static -O2 oshash.m -lobjc -o oshash
strip oshash 2>/dev/null || true

# Scheme (Gambit) — bundle libgambit
cd /repo/implementations/scheme
gsc -exe -o oshash oshash.scm
bundle_libs oshash
strip oshash 2>/dev/null || true

# Standard ML (Poly/ML) — bundle libpolyml
cd /repo/implementations/sml
polyc -o oshash oshash.sml
bundle_libs oshash
strip oshash 2>/dev/null || true

# COBOL (GnuCOBOL) — bundle libcob and friends
cd /repo/implementations/cobol
cobc -x -O2 -o oshash oshash.cob
bundle_libs oshash
strip oshash 2>/dev/null || true
'

echo "Built (verifying against breakdance.avi, expect 8e245d9679d31e12):"
for d in ada objc scheme sml cobol; do
    bin="$REPO/implementations/$d/oshash"
    [ -x "$bin" ] && printf "  %-8s %s\n" "$d" "$("$bin" "$REPO/public/downloads/breakdance.avi" 2>&1)"
done

if [ "$RMI" -eq 1 ]; then
    echo "Removing builder image to reclaim disk..."
    docker rmi "$IMAGE" >/dev/null 2>&1 || true
fi
echo "Done."
