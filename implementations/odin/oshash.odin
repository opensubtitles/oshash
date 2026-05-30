// OpenSubtitles Hash (OSHash) - Odin implementation.
// hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB).
// u64 arithmetic wraps modulo 2^64; os.read_at reads at an absolute offset so
// the last 64 KB of a multi-GB file is read without streaming it.
package main

import "core:os"
import "core:fmt"

CHUNK :: 65536

sum_le :: proc(b: []u8) -> u64 {
	s: u64 = 0
	i := 0
	for i + 8 <= len(b) {
		w: u64 = 0
		for j := 0; j < 8; j += 1 {
			w |= u64(b[i + j]) << uint(8 * j)
		}
		s += w
		i += 8
	}
	return s
}

main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintln("Usage: oshash <file>")
		os.exit(1)
	}
	fd, oerr := os.open(os.args[1])
	if oerr != os.ERROR_NONE {
		os.exit(1)
	}
	defer os.close(fd)

	size, _ := os.file_size(fd)

	first := make([]u8, CHUNK)
	n1, _ := os.read_at(fd, first, 0)

	last_off: i64 = size > CHUNK ? size - CHUNK : 0
	last := make([]u8, CHUNK)
	n2, _ := os.read_at(fd, last, last_off)

	hash := u64(size) + sum_le(first[:n1]) + sum_le(last[:n2])
	fmt.printf("%016x\n", hash)
}
