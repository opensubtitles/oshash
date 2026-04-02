// OpenSubtitles Hash (OSHash) - V implementation.
// Algorithm: file_size + sum_uint64_le(first_64KB) + sum_uint64_le(last_64KB)
import os

const chunk_size = 65536

fn compute_hash(filepath string) !string {
	mut f := os.open(filepath)!
	fsize := os.file_size(filepath)
	mut hash := u64(fsize)

	mut buf := []u8{len: chunk_size}

	// Hash first 64KB
	f.read(mut buf)!
	for i := 0; i < chunk_size / 8; i++ {
		val := u64(buf[i * 8]) |
			(u64(buf[i * 8 + 1]) << 8) |
			(u64(buf[i * 8 + 2]) << 16) |
			(u64(buf[i * 8 + 3]) << 24) |
			(u64(buf[i * 8 + 4]) << 32) |
			(u64(buf[i * 8 + 5]) << 40) |
			(u64(buf[i * 8 + 6]) << 48) |
			(u64(buf[i * 8 + 7]) << 56)
		hash += val
	}

	// Hash last 64KB
	f.seek(i64(fsize) - chunk_size, .start)!
	f.read(mut buf)!
	for i := 0; i < chunk_size / 8; i++ {
		val := u64(buf[i * 8]) |
			(u64(buf[i * 8 + 1]) << 8) |
			(u64(buf[i * 8 + 2]) << 16) |
			(u64(buf[i * 8 + 3]) << 24) |
			(u64(buf[i * 8 + 4]) << 32) |
			(u64(buf[i * 8 + 5]) << 40) |
			(u64(buf[i * 8 + 6]) << 48) |
			(u64(buf[i * 8 + 7]) << 56)
		hash += val
	}

	f.close()

	return '${hash:016x}'
}

fn main() {
	if os.args.len < 2 {
		eprintln('Usage: oshash <file>')
		exit(1)
	}
	result := compute_hash(os.args[1]) or {
		eprintln('Error: ${err}')
		exit(1)
	}
	println(result)
}
