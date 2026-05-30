#!/bin/bash
# OpenSubtitles Hash - Master Test Suite
# Tests all implementations against known reference hashes.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMPL_DIR="$SCRIPT_DIR/implementations"

# Add custom install paths
export PATH="/home/claude/local/go/bin:/home/claude/.cargo/bin:/home/claude/local/nim/bin:/home/claude/local/dart-sdk/bin:/home/claude/local/kotlinc/bin:/home/claude/local/pwsh:$PATH"
export GOPATH="/home/claude/go"

# GNU time (if present) gives per-run wall time, CPU%, and peak memory. Each
# implementation is timed on its run against the first reference vector — the
# same file for everyone, so the numbers are comparable. Note these are
# whole-process figures: for hashing only first+last 64KB, interpreter/VM
# startup dominates, which is exactly what makes the comparison interesting.
TIME_BIN=""
[ -x /usr/bin/time ] && TIME_BIN=/usr/bin/time

# Reference test vectors: "file|expected_hash|label"
# We verify against the canonical files published at
# https://opensubtitles.github.io/oshash/#test-vectors — breakdance.avi and the
# 4 GB file from dummy.rar (added below) — rather than our own synthetic files.
TEST_VECTORS=(
    "$SCRIPT_DIR/public/downloads/breakdance.avi|8e245d9679d31e12|breakdance.avi (12,909,756 bytes, official OpenSubtitles reference)"
)

# >4 GB overflow vector. The repo ships dummy.rar (~2.4 MB) which unpacks to a
# 4,295,033,890-byte file. 64-bit wrap behaviour is the #1 source of buggy
# implementations (it caught real bugs in the Perl and PHP ports), so we unpack
# it here, test against it, then delete it on exit so it never permanently
# occupies ~4 GB of disk. Skipped gracefully if dummy.rar or an unpacker is absent.
DUMMY_RAR="$SCRIPT_DIR/public/downloads/dummy.rar"
DUMMY_4GB=""
cleanup_dummy() { [ -n "$DUMMY_4GB" ] && rm -f "$DUMMY_4GB"; }
trap cleanup_dummy EXIT

if [ -f "$DUMMY_RAR" ]; then
    UNPACKER=""
    command -v unrar >/dev/null 2>&1 && UNPACKER="unrar"
    [ -z "$UNPACKER" ] && command -v 7z >/dev/null 2>&1 && UNPACKER="7z"

    if [ -n "$UNPACKER" ]; then
        echo "  Unpacking 4 GB overflow vector from dummy.rar (auto-deleted after run)..."
        DUMMY_4GB="$SCRIPT_DIR/test-data/dummy-4gb.bin"
        rm -f "$DUMMY_4GB" "$SCRIPT_DIR/test-data/dummy.bin"
        if [ "$UNPACKER" = "unrar" ]; then
            unrar x -inul -o+ "$DUMMY_RAR" "$SCRIPT_DIR/test-data/" >/dev/null 2>&1 || true
        else
            7z e -y -o"$SCRIPT_DIR/test-data" "$DUMMY_RAR" >/dev/null 2>&1 || true
        fi
        # The archive member is named dummy.bin; normalise to dummy-4gb.bin.
        [ -f "$SCRIPT_DIR/test-data/dummy.bin" ] && mv -f "$SCRIPT_DIR/test-data/dummy.bin" "$DUMMY_4GB"
        if [ -f "$DUMMY_4GB" ]; then
            TEST_VECTORS+=("$DUMMY_4GB|61f7751fc2a72bfb|dummy 4 GB file (>4 GB, 64-bit overflow)")
        else
            echo "  (failed to unpack dummy.rar — skipping 4 GB vector)"
            DUMMY_4GB=""
        fi
    else
        echo "  (no unrar/7z available — skipping 4 GB overflow vector)"
    fi
fi

PASS=0
FAIL=0
SKIP=0
TOTAL=0
RESULTS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  OpenSubtitles Hash (OSHash) - Implementation Test Suite${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Each implementation is checked against ${#TEST_VECTORS[@]} reference vector(s):"
    local vec file expected label
    for vec in "${TEST_VECTORS[@]}"; do
        IFS='|' read -r file expected label <<< "$vec"
        if [ -f "$file" ]; then
            echo -e "    ${BLUE}${expected}${NC}  ${label}"
        else
            echo -e "    ${YELLOW}(skip)${NC}           ${label} ${YELLOW}— file missing${NC}"
        fi
    done
    echo ""
    echo -e "${BOLD}───────────────────────────────────────────────────────────────${NC}"
}

run_test() {
    local lang="$1"
    local name="$2"
    local build_cmd="$3"
    local run_cmd="$4"
    local timeout_sec="${5:-30}"

    TOTAL=$((TOTAL + 1))

    printf "  %-20s" "$name"

    # Check if runtime/compiler exists
    if [ -n "$build_cmd" ]; then
        local compiler=$(echo "$build_cmd" | awk '{print $1}')
        if ! command -v "$compiler" &>/dev/null; then
            printf "${YELLOW}SKIP${NC} (${compiler} not installed)\n"
            SKIP=$((SKIP + 1))
            RESULTS+=("SKIP|$name|-|-|-|${compiler} not installed")
            return
        fi
    fi

    local runner=$(echo "$run_cmd" | awk '{print $1}')
    if ! command -v "$runner" &>/dev/null && [ ! -x "$runner" ]; then
        # For compiled languages, the binary may not exist yet (will be built)
        if [ -z "$build_cmd" ]; then
            printf "${YELLOW}SKIP${NC} (${runner} not installed)\n"
            SKIP=$((SKIP + 1))
            RESULTS+=("SKIP|$name|-|-|-|${runner} not installed")
            return
        fi
    fi

    # Build step
    if [ -n "$build_cmd" ]; then
        local build_output
        build_output=$(eval "$build_cmd" 2>&1)
        if [ $? -ne 0 ]; then
            printf "${RED}FAIL${NC} (build error)\n"
            FAIL=$((FAIL + 1))
            RESULTS+=("FAIL|$name|-|-|-|Build error: $(echo "$build_output" | head -3)")
            return
        fi
    fi

    # Run against every reference vector. stdin is redirected from /dev/null so
    # an implementation that tries to read the terminal (e.g. the Scala runner)
    # gets EOF instead of being stopped by SIGTTIN and hanging forever.
    # pipefail (inside the subshell) makes $? reflect the implementation's exit
    # code rather than tr's, so crashes and timeouts are detected reliably.
    local vec file expected label result exit_code stderr_out tmp_stderr short
    local secs="-" cpu="-" mem="-"

    # Benchmark against the largest available vector — the 4 GB file when it has
    # been unpacked, otherwise breakdance.avi. A correct OSHash reads only the
    # first and last 64 KB regardless of size, so this also flushes out any
    # implementation that secretly streams the whole file.
    local bench_file=""
    for vec in "${TEST_VECTORS[@]}"; do
        IFS='|' read -r file _ _ <<< "$vec"
        [ -f "$file" ] && bench_file="$file"
    done

    for vec in "${TEST_VECTORS[@]}"; do
        IFS='|' read -r file expected label <<< "$vec"
        [ -f "$file" ] || continue   # skip vectors whose file isn't present
        short="${label%% *}"

        tmp_stderr=$(mktemp)
        if [ -n "$TIME_BIN" ] && [ "$file" = "$bench_file" ]; then
            # Time the benchmark vector. Wall time comes from a millisecond-
            # resolution clock bracket (GNU time's %e is only 2 decimals, too
            # coarse for the fast compiled binaries); CPU% and peak RSS still
            # come from GNU time. Output goes to a file rather than a pipe so no
            # subshell/tr fork lands inside the timed window.
            local tmp_time=$(mktemp) tmp_out=$(mktemp) t0 t1
            t0=$(date +%s.%N)
            set +e   # a failing run must be recorded as FAIL, not abort the suite
            "$TIME_BIN" -f '%P|%M' -o "$tmp_time" \
                timeout "$timeout_sec" bash -c "$run_cmd \"$file\"" </dev/null >"$tmp_out" 2>"$tmp_stderr"
            exit_code=$?
            set -e
            t1=$(date +%s.%N)
            result=$(tr -d '[:space:]' < "$tmp_out")
            if [ "$exit_code" -eq 0 ] && [ -s "$tmp_time" ]; then
                IFS='|' read -r cpu mem < "$tmp_time"
                mem=$(awk "BEGIN{printf \"%.1f\", ${mem:-0}/1024}")        # KB -> MB
                secs=$(awk "BEGIN{printf \"%.3f\", $t1 - $t0}")           # seconds, ms resolution
            fi
            rm -f "$tmp_time" "$tmp_out"
        else
            result=$(set -o pipefail; timeout "$timeout_sec" bash -c "$run_cmd \"$file\"" </dev/null 2>"$tmp_stderr" | tr -d '[:space:]')
            exit_code=$?
        fi
        stderr_out=$(cat "$tmp_stderr")
        rm -f "$tmp_stderr"

        if [ $exit_code -ne 0 ]; then
            local why="runtime error"
            [ $exit_code -eq 124 ] && why="timed out (${timeout_sec}s)"
            printf "${RED}%-7s${NC}(${short}: ${why}, exit=$exit_code)\n" "FAIL"
            FAIL=$((FAIL + 1))
            RESULTS+=("FAIL|$name|-|-|-|${why} on $short (exit=$exit_code): $stderr_out")
            return
        fi

        if [ "$result" != "$expected" ]; then
            printf "${RED}%-7s${NC}(${short}: expected $expected, got $result)\n" "FAIL"
            FAIL=$((FAIL + 1))
            RESULTS+=("FAIL|$name|-|-|-|$short: expected $expected, got $result")
            return
        fi
    done

    local timestr="-" memstr="-"
    [ "$secs" != "-" ] && timestr="${secs}s"
    [ "$mem" != "-" ] && memstr="${mem} MB"
    printf "${GREEN}%-7s${NC}%8s %6s %10s\n" "PASS" "$timestr" "$cpu" "$memstr"
    PASS=$((PASS + 1))
    RESULTS+=("PASS|$name|$secs|$cpu|$mem|")
}

print_header

printf "  ${BOLD}%-20s%-7s%8s %6s %10s${NC}\n" "Language" "Result" "Time" "CPU" "Mem"
echo -e "  ─────────────────────────────────────────────────────"

# ─── Implementations are listed alphabetically (matching public/app.js) ───
# Note: Ada, COBOL, Forth, Objective-C, Prolog, Scheme, Smalltalk and Standard
# ML are built by tools/build_docker_langs.sh (no host toolchain); they SKIP
# gracefully if that build hasn't been run.

# Ada
run_test "ada" "Ada" \
    "" \
    "$IMPL_DIR/ada/oshash"

# AWK (gawk)
run_test "awk" "AWK" \
    "" \
    "gawk -f $IMPL_DIR/awk/oshash.awk"

# Bash
run_test "bash" "Bash" \
    "" \
    "bash $IMPL_DIR/bash/oshash.sh" 120

# C
run_test "c" "C" \
    "gcc -o $IMPL_DIR/c/oshash $IMPL_DIR/c/oshash.c" \
    "$IMPL_DIR/c/oshash"

# C++
run_test "cpp" "C++" \
    "g++ -o $IMPL_DIR/cpp/oshash $IMPL_DIR/cpp/oshash.cpp" \
    "$IMPL_DIR/cpp/oshash"

# C# (Mono)
run_test "csharp" "C#" \
    "mcs -out:$IMPL_DIR/csharp/oshash.exe $IMPL_DIR/csharp/oshash.cs" \
    "mono $IMPL_DIR/csharp/oshash.exe"

# Clojure
CLOJURE_CP="/home/claude/local/clojure/clojure.jar:/home/claude/local/clojure/spec.alpha.jar:/home/claude/local/clojure/core.specs.alpha.jar"
run_test "clojure" "Clojure" \
    "" \
    "java -cp $CLOJURE_CP clojure.main $IMPL_DIR/clojure/oshash.clj" 60

# COBOL — built by tools/build_docker_langs.sh
run_test "cobol" "COBOL" \
    "" \
    "$IMPL_DIR/cobol/oshash"

# Common Lisp (SBCL)
run_test "lisp" "Common Lisp" \
    "" \
    "sbcl --script $IMPL_DIR/lisp/oshash.lisp"

# Crystal
run_test "crystal" "Crystal" \
    "crystal build --release -o $IMPL_DIR/crystal/oshash $IMPL_DIR/crystal/oshash.cr 2>/dev/null" \
    "$IMPL_DIR/crystal/oshash" 60

# D
run_test "d" "D" \
    "ldc2 -of=$IMPL_DIR/d/oshash $IMPL_DIR/d/oshash.d 2>/dev/null" \
    "$IMPL_DIR/d/oshash"

# Dart
run_test "dart" "Dart" \
    "" \
    "dart run $IMPL_DIR/dart/oshash.dart"

# Elixir
run_test "elixir" "Elixir" \
    "" \
    "elixir $IMPL_DIR/elixir/oshash.exs"

# Erlang
run_test "erlang" "Erlang" \
    "" \
    "escript $IMPL_DIR/erlang/oshash.erl"

# F#
run_test "fsharp" "F#" \
    "fsharpc --nologo -o:$IMPL_DIR/fsharp/oshash.exe $IMPL_DIR/fsharp/oshash.fsx 2>/dev/null" \
    "mono $IMPL_DIR/fsharp/oshash.exe"

# Forth (gforth) — built by tools/build_docker_langs.sh
run_test "forth" "Forth" \
    "" \
    "$IMPL_DIR/forth/gforth-bin --image-file $IMPL_DIR/forth/gforth.fi $IMPL_DIR/forth/oshash.fs"

# Fortran
run_test "fortran" "Fortran" \
    "gfortran -O2 -o $IMPL_DIR/fortran/oshash $IMPL_DIR/fortran/oshash.f90 2>/dev/null" \
    "$IMPL_DIR/fortran/oshash"

# Go
run_test "go" "Go" \
    "go build -o $IMPL_DIR/go/oshash $IMPL_DIR/go/oshash.go" \
    "$IMPL_DIR/go/oshash"

# Groovy
run_test "groovy" "Groovy" \
    "" \
    "groovy $IMPL_DIR/groovy/oshash.groovy"

# Haskell (pre-compiled binary, GHC removed to save space)
run_test "haskell" "Haskell" \
    "" \
    "$IMPL_DIR/haskell/oshash"

# Java
run_test "java" "Java" \
    "javac -d $IMPL_DIR/java $IMPL_DIR/java/OSHash.java" \
    "java -cp $IMPL_DIR/java OSHash"

# JavaScript (Node.js)
run_test "nodejs" "JavaScript" \
    "" \
    "node $IMPL_DIR/nodejs/oshash.js"

# Julia
run_test "julia" "Julia" \
    "" \
    "julia $IMPL_DIR/julia/oshash.jl" 60

# Kotlin
run_test "kotlin" "Kotlin" \
    "kotlinc $IMPL_DIR/kotlin/oshash.kt -include-runtime -d $IMPL_DIR/kotlin/oshash.jar 2>/dev/null" \
    "java -jar $IMPL_DIR/kotlin/oshash.jar" 120

# Lua
run_test "lua" "Lua" \
    "" \
    "lua5.3 $IMPL_DIR/lua/oshash.lua"

# Nim
run_test "nim" "Nim" \
    "nim c -d:release -o:$IMPL_DIR/nim/oshash $IMPL_DIR/nim/oshash.nim 2>/dev/null" \
    "$IMPL_DIR/nim/oshash"

# Objective-C — built by tools/build_docker_langs.sh
run_test "objc" "Objective-C" \
    "" \
    "$IMPL_DIR/objc/oshash"

# OCaml
run_test "ocaml" "OCaml" \
    "ocamlopt -o $IMPL_DIR/ocaml/oshash $IMPL_DIR/ocaml/oshash.ml 2>/dev/null" \
    "$IMPL_DIR/ocaml/oshash"

# Pascal (Free Pascal)
run_test "pascal" "Pascal" \
    "fpc -o$IMPL_DIR/pascal/oshash $IMPL_DIR/pascal/oshash.pas -v0 2>/dev/null" \
    "$IMPL_DIR/pascal/oshash"

# Perl
run_test "perl" "Perl" \
    "" \
    "perl $IMPL_DIR/perl/oshash.pl"

# PHP
run_test "php" "PHP" \
    "" \
    "php $IMPL_DIR/php/oshash.php"

# PowerShell
run_test "powershell" "PowerShell" \
    "" \
    "pwsh -File $IMPL_DIR/powershell/oshash.ps1 -Path"

# Prolog (GNU Prolog) — built by tools/build_docker_langs.sh
run_test "prolog" "Prolog" \
    "" \
    "$IMPL_DIR/prolog/oshash"

# Python
run_test "python" "Python" \
    "" \
    "python3 $IMPL_DIR/python/oshash.py"

# R
run_test "r" "R" \
    "" \
    "Rscript $IMPL_DIR/r/oshash.R"

# Raku
run_test "raku" "Raku" \
    "" \
    "raku $IMPL_DIR/raku/oshash.raku" 60

# Ruby
run_test "ruby" "Ruby" \
    "" \
    "ruby $IMPL_DIR/ruby/oshash.rb"

# Rust
run_test "rust" "Rust" \
    "cd $IMPL_DIR/rust && cargo build --release -q 2>&1 | tail -1" \
    "$IMPL_DIR/rust/target/release/oshash"

# Scala
run_test "scala" "Scala" \
    "scalac -d $IMPL_DIR/scala $IMPL_DIR/scala/oshash.scala 2>/dev/null" \
    "scala -cp $IMPL_DIR/scala OSHash"

# Scheme (Gambit) — built by tools/build_docker_langs.sh
run_test "scheme" "Scheme" \
    "" \
    "$IMPL_DIR/scheme/oshash"

# Smalltalk (GNU Smalltalk) — built by tools/build_docker_langs.sh
run_test "smalltalk" "Smalltalk" \
    "" \
    "$IMPL_DIR/smalltalk/gst-bin --image $IMPL_DIR/smalltalk/gst.im $IMPL_DIR/smalltalk/oshash.st -a"

# Standard ML (Poly/ML) — built by tools/build_docker_langs.sh
run_test "sml" "Standard ML" \
    "" \
    "$IMPL_DIR/sml/oshash"

# Swift
run_test "swift" "Swift" \
    "swiftc -O -o $IMPL_DIR/swift/oshash $IMPL_DIR/swift/oshash.swift 2>/dev/null" \
    "$IMPL_DIR/swift/oshash" 60

# Tcl
run_test "tcl" "Tcl" \
    "" \
    "tclsh $IMPL_DIR/tcl/oshash.tcl"

# TypeScript (runs as JS via node, suppress module warnings)
run_test "typescript" "TypeScript" \
    "" \
    "node --no-warnings $IMPL_DIR/typescript/oshash.ts"

# V
run_test "vlang" "V" \
    "v -o $IMPL_DIR/vlang/oshash $IMPL_DIR/vlang/oshash.v 2>/dev/null" \
    "$IMPL_DIR/vlang/oshash"

# Vala
run_test "vala" "Vala" \
    "valac --pkg gio-2.0 -o $IMPL_DIR/vala/oshash $IMPL_DIR/vala/oshash.vala 2>/dev/null" \
    "$IMPL_DIR/vala/oshash"

# x86-64 Assembly (NASM)
run_test "asm" "x86-64 Assembly" \
    "nasm -f elf64 -o $IMPL_DIR/asm/oshash.o $IMPL_DIR/asm/oshash.asm && ld -o $IMPL_DIR/asm/oshash $IMPL_DIR/asm/oshash.o" \
    "$IMPL_DIR/asm/oshash"

# Zig
run_test "zig" "Zig" \
    "zig build-exe -O ReleaseFast $IMPL_DIR/zig/oshash.zig -femit-bin=$IMPL_DIR/zig/oshash 2>/dev/null" \
    "$IMPL_DIR/zig/oshash"

echo ""
echo -e "${BOLD}───────────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "  ${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}  ${YELLOW}SKIP: $SKIP${NC}  Total: $TOTAL"
echo ""

# JSON output for the web page
JSON_FILE="$SCRIPT_DIR/test-results.json"
echo "[" > "$JSON_FILE"
first=true
for r in "${RESULTS[@]}"; do
    # Format: status|name|timeSec|cpu|memMB|detail  (detail is last so any '|'
    # in stderr stays inside it).
    IFS='|' read -r status name secs cpu mem detail <<< "$r"
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$JSON_FILE"
    fi
    # Escape quotes in detail
    detail=$(echo "$detail" | sed 's/"/\\"/g')
    printf '  {"language": "%s", "status": "%s", "timeSec": "%s", "cpu": "%s", "memMB": "%s", "detail": "%s"}' \
        "$name" "$status" "$secs" "$cpu" "$mem" "$detail" >> "$JSON_FILE"
done
echo "" >> "$JSON_FILE"
echo "]" >> "$JSON_FILE"

echo -e "  Results saved to: ${BLUE}test-results.json${NC}"
echo ""

# Exit with failure if any tests failed
if [ $FAIL -gt 0 ]; then
    exit 1
fi
