#!/bin/bash
# Build the OSHash implementations whose toolchains we don't keep on the host.
#
# Each is compiled inside the throwaway `oshash-builder` image (Ubuntu 22.04, so
# the binaries are glibc-compatible with the host). Native runtimes are either
# statically linked (Ada) or bundled beside the binary with an $ORIGIN rpath
# (Scheme/Gambit's libgambit), so the resulting binary runs on the host with no
# toolchain installed. test_all.sh then runs these like any other compiled
# implementation. Pass --rmi to delete the builder image afterwards and reclaim
# the disk (the binaries persist, so normal test runs keep working).
set -e

REPO="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="oshash-builder"
RMI=0
[ "$1" = "--rmi" ] && RMI=1

if ! command -v docker >/dev/null 2>&1; then
    echo "docker not available — cannot build the Docker-only languages." >&2
    exit 1
fi

echo "Building $IMAGE image (Ada, Scheme toolchains)..."
docker build -q -f "$REPO/tools/Dockerfile.builder" -t "$IMAGE" "$REPO" >/dev/null

echo "Compiling implementations inside the container..."
docker run --rm -v "$REPO:/repo" -w /repo "$IMAGE" bash -c '
set -e

# ── Ada: fully static native binary ──────────────────────────────────────────
cd /repo/implementations/ada
gnatmake -q oshash.adb -o oshash -largs -static
strip oshash 2>/dev/null || true

# ── Scheme (Gambit): native binary + bundled libgambit with $ORIGIN rpath ─────
cd /repo/implementations/scheme
gsc -exe -o oshash oshash.scm
# Bundle only libs absent from a stock Ubuntu host (libgambit); libc/ssl/crypto
# are already present on the host.
for lib in $(ldd oshash | awk "/libgambit/{print \$3}"); do
    cp -f "$lib" .
done
patchelf --set-rpath "\$ORIGIN" oshash
strip oshash 2>/dev/null || true
'

echo "Built:"
for d in ada scheme; do
    bin="$REPO/implementations/$d/oshash"
    [ -x "$bin" ] && printf "  %-8s %s\n" "$d" "$("$bin" "$REPO/public/downloads/breakdance.avi") (expect 8e245d9679d31e12)"
done

if [ "$RMI" -eq 1 ]; then
    echo "Removing builder image to reclaim disk..."
    docker rmi "$IMAGE" >/dev/null 2>&1 || true
fi
echo "Done."
