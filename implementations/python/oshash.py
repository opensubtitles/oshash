#!/usr/bin/env python3
"""
OpenSubtitles Hash (OSHash) - Python implementation.
Algorithm: file_size + uint64_le_sum(first_64KB) + uint64_le_sum(last_64KB)
All arithmetic wraps at 64 bits.
"""
import struct
import sys
import os

CHUNK_SIZE = 65536  # 64 KB
LONG_LONG_FORMAT = '<q'  # little-endian signed int64
BYTE_SIZE = struct.calcsize(LONG_LONG_FORMAT)


def compute_hash(filepath: str) -> str:
    filesize = os.path.getsize(filepath)
    if filesize < CHUNK_SIZE * 2:
        raise ValueError(f"File too small: {filesize} bytes (minimum {CHUNK_SIZE * 2})")

    hash_val = filesize
    iterations = CHUNK_SIZE // BYTE_SIZE

    with open(filepath, "rb") as f:
        # Hash first 64KB
        for _ in range(iterations):
            buf = f.read(BYTE_SIZE)
            (val,) = struct.unpack(LONG_LONG_FORMAT, buf)
            hash_val += val
            hash_val &= 0xFFFFFFFFFFFFFFFF

        # Hash last 64KB
        f.seek(max(0, filesize - CHUNK_SIZE), 0)
        for _ in range(iterations):
            buf = f.read(BYTE_SIZE)
            (val,) = struct.unpack(LONG_LONG_FORMAT, buf)
            hash_val += val
            hash_val &= 0xFFFFFFFFFFFFFFFF

    return "%016x" % hash_val


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <file>")
        sys.exit(1)
    filepath = sys.argv[1]
    result = compute_hash(filepath)
    print(result)
