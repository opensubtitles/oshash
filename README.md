# OSHash — OpenSubtitles Hash

The **OpenSubtitles Hash** (OSHash) is a fast file identification algorithm used by [OpenSubtitles](https://www.opensubtitles.org) to match video files with subtitles. This repository contains **46 verified implementations** across every major programming language, a test suite, and a reference website.

**Website:** [opensubtitles.github.io/oshash](https://opensubtitles.github.io/oshash)

## Algorithm

```
hash = file_size + sum_uint64_le(first_64KB) + sum_uint64_le(last_64KB)
```

1. Start with the file size as a 64-bit unsigned integer
2. Read the first 64 KB (65,536 bytes) as 8,192 little-endian `uint64` values and add them to the hash
3. Read the last 64 KB the same way and add them to the hash
4. All arithmetic wraps at 64 bits (unsigned overflow)

**Minimum file size:** 128 KB (131,072 bytes). Only 128 KB of data is ever read, regardless of file size — hashing a 50 GB file takes the same time as a 200 KB file.

**Origin:** First implemented in [Media Player Classic](https://github.com/mpc-hc/mpc-hc) by Gabest ([original source](https://github.com/mpc-hc/mpc-hc/blob/develop/src/mpc-hc/SubtitlesProvidersUtils.cpp#L791)).

## Implementations

| Category | Languages |
|----------|-----------|
| **Systems** | [C](implementations/c/oshash.c), [C++](implementations/cpp/oshash.cpp), [Rust](implementations/rust/src/main.rs), [Zig](implementations/zig/oshash.zig), [Go](implementations/go/oshash.go), [D](implementations/d/oshash.d), [Nim](implementations/nim/oshash.nim), [Crystal](implementations/crystal/oshash.cr), [Swift](implementations/swift/oshash.swift) |
| **JVM** | [Java](implementations/java/OSHash.java), [Kotlin](implementations/kotlin/oshash.kt), [Scala](implementations/scala/oshash.scala), [Groovy](implementations/groovy/oshash.groovy), [Clojure](implementations/clojure/oshash.clj) |
| **.NET** | [C#](implementations/csharp/oshash.cs), [F#](implementations/fsharp/oshash.fsx) |
| **Scripting** | [Python](implementations/python/oshash.py), [Node.js](implementations/nodejs/oshash.js), [TypeScript](implementations/typescript/oshash.ts), [Ruby](implementations/ruby/oshash.rb), [PHP](implementations/php/oshash.php), [Perl](implementations/perl/oshash.pl), [Lua](implementations/lua/oshash.lua), [Elixir](implementations/elixir/oshash.exs), [R](implementations/r/oshash.R), [Dart](implementations/dart/oshash.dart), [Julia](implementations/julia/oshash.jl), [Raku](implementations/raku/oshash.raku) |
| **Shell** | [Bash](implementations/bash/oshash.sh), [PowerShell](implementations/powershell/oshash.ps1), [AWK](implementations/awk/oshash.awk), [Tcl](implementations/tcl/oshash.tcl) |
| **Functional** | [Haskell](implementations/haskell/oshash.hs), [OCaml](implementations/ocaml/oshash.ml), [Common Lisp](implementations/lisp/oshash.lisp), [Erlang](implementations/erlang/oshash.erl), [Scheme](implementations/scheme/oshash.scm), [Standard ML](implementations/sml/oshash.sml) |
| **Other** | [Ada](implementations/ada/oshash.adb), [COBOL](implementations/cobol/oshash.cob), [Objective-C](implementations/objc/oshash.m), [Pascal](implementations/pascal/oshash.pas), [Vala](implementations/vala/oshash.vala), [Fortran](implementations/fortran/oshash.f90), [V](implementations/vlang/oshash.v), [x86-64 Assembly](implementations/asm/oshash.asm) |

> **Ada**, **COBOL**, **Objective-C**, **Scheme** (Gambit) and **Standard ML** (Poly/ML) are built inside a throwaway Docker image (no host toolchain) — run `bash tools/build_docker_langs.sh` once; pass `--rmi` to delete the image afterwards. The resulting binaries run on the host on their own.

Every implementation:
- Takes a file path as a CLI argument
- Prints the 16-character lowercase hex hash to stdout
- Has been verified against the canonical reference files (`breakdance.avi` and the 4 GB file from `dummy.rar`, including the >4 GB 64-bit-overflow case)

## Test Vectors

| File | Size (bytes) | Expected Hash |
|------|-------------|---------------|
| `breakdance.avi` | 12,909,756 | `8e245d9679d31e12` |
| `dummy.rar` (unpacked) | 4,295,033,890 | `61f7751fc2a72bfb` |

Download test files from the [reference page](https://opensubtitles.github.io/oshash/#test-vectors).

## Quick Start

### Use an implementation

```bash
# Python
python3 implementations/python/oshash.py /path/to/video.mkv

# Node.js
node implementations/nodejs/oshash.js /path/to/video.mkv

# Go (compile first)
go build -o oshash implementations/go/oshash.go
./oshash /path/to/video.mkv
```

### Run the test suite

```bash
# Generate test files
python3 test-data/generate_testfile.py

# Run all tests (requires language runtimes to be installed)
bash test_all.sh
```

### Run the website locally

```bash
npm install
node server.js --dev    # http://localhost:3005 with live reload
```

## Adding a New Language

1. Create `implementations/{lang}/oshash.{ext}` — CLI program: takes file path, prints 16-char hex hash
2. Add a `run_test` entry in `test_all.sh`
3. Add the source file mapping in `server.js`
4. Add the language to the `LANGUAGES` array in `public/app.js`
5. Run `bash test_all.sh` to verify

## Security Notice

OSHash is **not** a cryptographic hash. It is designed for speed, not security. Do not use it for integrity verification or authentication. Two files with the same size, same first 64 KB, and same last 64 KB will produce the same hash regardless of content in between. See the [security analysis](https://opensubtitles.github.io/oshash/#security) for details.

## License

MIT
