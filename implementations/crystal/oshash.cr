# OpenSubtitles Hash (OSHash) - Crystal implementation.
# Algorithm: file_size + sum_le_u64(first_64KB) + sum_le_u64(last_64KB)

CHUNK_SIZE = 65536

def compute_hash(filepath : String) : String
  filesize = File.size(filepath).to_u64
  hash = filesize

  File.open(filepath, "rb") do |f|
    # Hash first 64KB
    buf = Bytes.new(CHUNK_SIZE)
    f.read_fully(buf)
    (CHUNK_SIZE // 8).times do |i|
      val = IO::ByteFormat::LittleEndian.decode(UInt64, buf[i * 8, 8])
      hash &+= val
    end

    # Hash last 64KB
    f.seek(Math.max(0_i64, filesize.to_i64 - CHUNK_SIZE))
    f.read_fully(buf)
    (CHUNK_SIZE // 8).times do |i|
      val = IO::ByteFormat::LittleEndian.decode(UInt64, buf[i * 8, 8])
      hash &+= val
    end
  end

  "%016x" % hash
end

abort "Usage: oshash <file>" if ARGV.empty?
puts compute_hash(ARGV[0])
