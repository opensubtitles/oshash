#!/usr/bin/env lua
-- OpenSubtitles Hash (OSHash) - Lua implementation.
-- Works on both big and little endian architectures.

local function compute_hash(fileName)
    local fil = io.open(fileName, "rb")
    if not fil then
        io.stderr:write("Error opening file: " .. fileName .. "\n")
        os.exit(1)
    end

    local lo, hi = 0, 0

    -- Hash first 64KB (8192 x 8 bytes)
    for i = 1, 8192 do
        local a, b, c, d = fil:read(4):byte(1, 4)
        lo = lo + a + b * 256 + c * 65536 + d * 16777216
        a, b, c, d = fil:read(4):byte(1, 4)
        hi = hi + a + b * 256 + c * 65536 + d * 16777216
        while lo >= 4294967296 do
            lo = lo - 4294967296
            hi = hi + 1
        end
        while hi >= 4294967296 do
            hi = hi - 4294967296
        end
    end

    -- Hash last 64KB
    local size = fil:seek("end", -65536) + 65536
    for i = 1, 8192 do
        local a, b, c, d = fil:read(4):byte(1, 4)
        lo = lo + a + b * 256 + c * 65536 + d * 16777216
        a, b, c, d = fil:read(4):byte(1, 4)
        hi = hi + a + b * 256 + c * 65536 + d * 16777216
        while lo >= 4294967296 do
            lo = lo - 4294967296
            hi = hi + 1
        end
        while hi >= 4294967296 do
            hi = hi - 4294967296
        end
    end

    -- Add file size. Split into 32-bit halves and carry in O(1): a subtraction
    -- loop here would run size/2^32 times (billions for a multi-EB file), and
    -- lo + size could also overflow Lua's 64-bit integer.
    hi = hi + (size // 4294967296)
    lo = lo + (size % 4294967296)
    hi = (hi + (lo // 4294967296)) % 4294967296
    lo = lo % 4294967296

    fil:close()
    return string.format("%08x%08x", hi, lo), size
end

if not arg[1] then
    io.stderr:write("Usage: lua oshash.lua <file>\n")
    os.exit(1)
end

local hash = compute_hash(arg[1])
print(hash)
