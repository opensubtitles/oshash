#!/usr/bin/env python3
"""Generate a deterministic 128 KB test file whose OSHash has leading zero
hex digits, to catch implementations that don't zero-pad the hash to 16
characters. (The canonical breakdance.avi / 4 GB vectors have no leading
zeros, so they can't catch this class of bug.)

Writes test-data/zerohash.bin and prints its expected 16-char hash."""
import os
import struct

CHUNK = 65536
SIZE = 2 * CHUNK            # 131072: first and last 64 KB tile the file exactly
MASK = (1 << 64) - 1
PATH = os.path.join(os.path.dirname(__file__), "zerohash.bin")


def oshash(data):
    h = len(data)
    for i in range(0, CHUNK, 8):
        h = (h + struct.unpack_from("<Q", data, i)[0]) & MASK
    for i in range(SIZE - CHUNK, SIZE, 8):
        h = (h + struct.unpack_from("<Q", data, i)[0]) & MASK
    return h


def main():
    # Deterministic pseudo-random content (no external seed dependency).
    data = bytearray((i * 1103515245 + 12345) & 0xFF for i in range(SIZE))

    # The hash is linear in the 64-bit words, so solve the first word to drive
    # the top 16 bits of the hash to zero (-> at least 4 leading hex zeros).
    h = oshash(data)
    target = h & 0x0000FFFFFFFFFFFF
    w0 = struct.unpack_from("<Q", data, 0)[0]
    new_w0 = (w0 + (target - h)) & MASK
    struct.pack_into("<Q", data, 0, new_w0)

    with open(PATH, "wb") as f:
        f.write(data)

    print("%016x" % oshash(data))


if __name__ == "__main__":
    main()
