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

# GNU Prolog — native binary (links only libc/libm, runs on the host as-is)
cd /repo/implementations/prolog
gplc oshash.pl -o oshash
strip oshash 2>/dev/null || true

# Forth (gforth) — bundle the engine binary + its image
cd /repo/implementations/forth
cp -f "$(command -v gforth-fast)" gforth-bin
cp -f "$(find /usr/lib -name gforth.fi | head -1)" gforth.fi
bundle_libs gforth-bin

# Smalltalk (GNU Smalltalk) — bundle the VM + its image
cd /repo/implementations/smalltalk
cp -f "$(command -v gst)" gst-bin
cp -f /usr/lib/gnu-smalltalk/gst.im gst.im
bundle_libs gst-bin

# Modula-2 (GNU Modula-2) — native binary, bundle the m2 runtime libs
cd /repo/implementations/modula2
gm2 -O2 -o oshash oshash.mod -flibs=m2pim,m2iso
bundle_libs oshash
strip oshash 2>/dev/null || true

# Odin — native binary (links only libc/libm, runs on the host as-is)
cd /repo/implementations/odin
odin build oshash.odin -file -out:oshash -o:speed
strip oshash 2>/dev/null || true

# Pony — native binary; bundle any non-system libs
cd /repo/implementations/pony
ponyc . -b oshash -o . >/dev/null
rm -f oshash.o
bundle_libs oshash
strip oshash 2>/dev/null || true

# Algol 68 (Algol 68 Genie) — interpreted; bundle the a68g interpreter
cd /repo/implementations/algol68
cp -f "$(command -v a68g)" a68g-bin
bundle_libs a68g-bin

# Rexx (Regina) — the rexx interpreter is statically linked; just bundle it
cd /repo/implementations/rexx
cp -f "$(command -v rexx)" rexx-bin
bundle_libs rexx-bin

# Racket — raco distribute makes a self-contained tree (~48 MB)
cd /repo/implementations/racket
raco exe -o oshash-exe oshash.rkt >/dev/null
rm -rf dist && raco distribute dist oshash-exe >/dev/null
rm -f oshash-exe
'

BD="$REPO/public/downloads/breakdance.avi"
I="$REPO/implementations"
echo "Built (verifying against breakdance.avi, expect 8e245d9679d31e12):"
for d in ada objc scheme sml cobol prolog modula2 odin pony; do
    [ -x "$I/$d/oshash" ] && printf "  %-10s %s\n" "$d" "$("$I/$d/oshash" "$BD" 2>/dev/null)"
done
[ -x "$I/algol68/a68g-bin" ] && printf "  %-10s %s\n" "algol68" \
    "$("$I/algol68/a68g-bin" --script "$I/algol68/oshash.a68" "$BD" 2>/dev/null)"
[ -x "$I/rexx/rexx-bin" ] && printf "  %-10s %s\n" "rexx" \
    "$("$I/rexx/rexx-bin" "$I/rexx/oshash.rexx" "$BD" 2>/dev/null)"
[ -x "$I/racket/dist/bin/oshash-exe" ] && printf "  %-10s %s\n" "racket" \
    "$("$I/racket/dist/bin/oshash-exe" "$BD" 2>/dev/null)"
[ -x "$I/forth/gforth-bin" ] && printf "  %-10s %s\n" "forth" \
    "$("$I/forth/gforth-bin" --image-file "$I/forth/gforth.fi" "$I/forth/oshash.fs" "$BD" 2>/dev/null)"
[ -x "$I/smalltalk/gst-bin" ] && printf "  %-10s %s\n" "smalltalk" \
    "$("$I/smalltalk/gst-bin" --image "$I/smalltalk/gst.im" "$I/smalltalk/oshash.st" -a "$BD" 2>/dev/null)"

if [ "$RMI" -eq 1 ]; then
    echo "Removing builder image to reclaim disk..."
    docker rmi "$IMAGE" >/dev/null 2>&1 || true
fi
echo "Done."
