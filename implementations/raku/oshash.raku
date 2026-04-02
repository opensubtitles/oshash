#!/usr/bin/env raku
# OpenSubtitles Hash (OSHash) - Raku implementation.
# Algorithm: file_size + sum_uint64_le(first_64KB) + sum_uint64_le(last_64KB)

constant CHUNK_SIZE = 65536;
constant MASK = 0xFFFFFFFFFFFFFFFF;

sub compute-hash(Str $filepath --> Str) {
    my $fh = $filepath.IO.open(:bin);
    my $fsize = $filepath.IO.s;

    my Int $hash = $fsize;

    # Hash first 64KB
    my $head = $fh.read(CHUNK_SIZE);
    for 0, 8 ...^ CHUNK_SIZE -> $i {
        $hash = ($hash + $head.read-uint64($i, LittleEndian)) +& MASK;
    }

    # Hash last 64KB
    $fh.seek($fsize - CHUNK_SIZE, SeekFromBeginning);
    my $tail = $fh.read(CHUNK_SIZE);
    for 0, 8 ...^ CHUNK_SIZE -> $i {
        $hash = ($hash + $tail.read-uint64($i, LittleEndian)) +& MASK;
    }

    $fh.close;
    sprintf('%016x', $hash);
}

sub MAIN(Str $file) {
    say compute-hash($file);
}
