#!/usr/bin/env python3
"""
Generate a deterministic test file for OpenSubtitles hash verification.
Uses a seeded PRNG so the file is always identical.
"""
import struct
import random

# We'll create two test files:
# 1. A "normal" file (~1MB) - easy to handle
# 2. A "small" file (exactly 128KB + 8 bytes) - edge case where head/tail overlap

SEED = 42
FILE_SIZE = 1_048_576  # 1 MB exactly

random.seed(SEED)
data = bytes(random.getrandbits(8) for _ in range(FILE_SIZE))

with open("/home/claude/projects/os/test-data/testfile.bin", "wb") as f:
    f.write(data)

# Also create a small edge-case file (just above 128KB)
SMALL_SIZE = 131080  # 128*1024 + 8
random.seed(123)
small_data = bytes(random.getrandbits(8) for _ in range(SMALL_SIZE))

with open("/home/claude/projects/os/test-data/testfile_small.bin", "wb") as f:
    f.write(small_data)

print(f"Generated testfile.bin: {FILE_SIZE} bytes")
print(f"Generated testfile_small.bin: {SMALL_SIZE} bytes")
