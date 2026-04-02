#!/usr/bin/env ruby
# OpenSubtitles Hash (OSHash) - Ruby implementation.

CHUNK_SIZE = 64 * 1024

def compute_hash(filename)
  filesize = File.size(filename)
  raise "File too small: #{filesize} bytes" if filesize < CHUNK_SIZE * 2

  hash = filesize

  File.open(filename, 'rb') do |f|
    # Hash first 64KB
    f.read(CHUNK_SIZE).unpack("Q<*").each do |n|
      hash = (hash + n) & 0xffffffffffffffff
    end

    # Hash last 64KB
    f.seek([0, filesize - CHUNK_SIZE].max, IO::SEEK_SET)
    f.read(CHUNK_SIZE).unpack("Q<*").each do |n|
      hash = (hash + n) & 0xffffffffffffffff
    end
  end

  sprintf("%016x", hash)
end

abort "Usage: #{$0} <file>" if ARGV.empty?
puts compute_hash(ARGV[0])
