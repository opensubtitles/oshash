# OpenSubtitles Hash (OSHash) - AWK implementation (gawk).
# Run with:  gawk -f oshash.awk <file>
#
# AWK has no binary I/O, so bytes are read via `od` (the same approach the Bash
# port uses). AWK numbers are IEEE doubles, so the hash is kept as four 16-bit
# words with explicit carry -- never as a full uint64 double, which would lose
# precision past 2^53 and silently corrupt large files.

function add64(acc, val,    i, s, carry) {
    carry = 0
    for (i = 0; i < 4; i++) {
        s = acc[i] + val[i] + carry
        acc[i] = s % 65536
        carry = (s >= 65536) ? 1 : 0
    }
}

# Sum one 64KB region (starting at byte `offset`) into the hash, reading it as
# little-endian unsigned 64-bit integers.
function sum_region(file, offset, hash,    cmd, line, b, word, n) {
    cmd = "od -An -v -t u1 -w8 -N 65536 -j " offset " '" file "'"
    while ((cmd | getline line) > 0) {
        n = split(line, b)
        if (n == 0) continue
        word[0] = b[1] + b[2] * 256
        word[1] = b[3] + b[4] * 256
        word[2] = b[5] + b[6] * 256
        word[3] = b[7] + b[8] * 256
        add64(hash, word)
    }
    close(cmd)
}

BEGIN {
    file = ARGV[1]
    ARGV[1] = ""            # don't let AWK try to read the data file as input
    if (file == "") {
        print "Usage: gawk -f oshash.awk <file>" > "/dev/stderr"
        exit 1
    }

    "stat -c%s '" file "'" | getline size
    close("stat -c%s '" file "'")

    # Seed the hash with the file size, split into 16-bit words.
    sz = size
    szword[0] = sz % 65536; sz = int(sz / 65536)
    szword[1] = sz % 65536; sz = int(sz / 65536)
    szword[2] = sz % 65536; sz = int(sz / 65536)
    szword[3] = sz % 65536
    add64(hash, szword)

    sum_region(file, 0, hash)
    last = size - 65536
    if (last < 0) last = 0
    sum_region(file, last, hash)

    printf "%04x%04x%04x%04x\n", hash[3], hash[2], hash[1], hash[0]
}
