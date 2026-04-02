// OpenSubtitles Hash (OSHash) - Go implementation.
package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"os"
)

const ChunkSize = 65536

func computeHash(file *os.File) (uint64, error) {
	fi, err := file.Stat()
	if err != nil {
		return 0, err
	}
	fsize := fi.Size()
	if fsize < ChunkSize*2 {
		return 0, fmt.Errorf("file too small: %d bytes", fsize)
	}

	buf := make([]byte, ChunkSize*2)

	// Read first 64KB
	if _, err := file.ReadAt(buf[:ChunkSize], 0); err != nil {
		return 0, err
	}
	// Read last 64KB
	if _, err := file.ReadAt(buf[ChunkSize:], fsize-ChunkSize); err != nil {
		return 0, err
	}

	var nums [ChunkSize * 2 / 8]uint64
	reader := bytes.NewReader(buf)
	if err := binary.Read(reader, binary.LittleEndian, &nums); err != nil {
		return 0, err
	}

	var hash uint64
	for _, num := range nums {
		hash += num
	}

	return hash + uint64(fsize), nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <file>\n", os.Args[0])
		os.Exit(1)
	}

	file, err := os.Open(os.Args[1])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	hash, err := computeHash(file)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("%016x\n", hash)
}
