#!/usr/bin/env julia
# OpenSubtitles Hash (OSHash) - Julia implementation.
# Algorithm: file_size + sum_le_u64(first_64KB) + sum_le_u64(last_64KB)

const CHUNK_SIZE = 65536

function compute_hash(filepath::String)::String
    fsize = filesize(filepath)
    hash = UInt64(fsize)

    open(filepath, "r") do f
        # Hash first 64KB
        buf = Vector{UInt64}(undef, CHUNK_SIZE ÷ 8)
        read!(f, buf)
        for val in buf
            hash += ltoh(val)  # little-to-host byte order
        end

        # Hash last 64KB
        seek(f, max(0, fsize - CHUNK_SIZE))
        read!(f, buf)
        for val in buf
            hash += ltoh(val)
        end
    end

    return string(hash, base=16, pad=16)
end

if length(ARGS) < 1
    println(stderr, "Usage: julia oshash.jl <file>")
    exit(1)
end
println(compute_hash(ARGS[1]))
