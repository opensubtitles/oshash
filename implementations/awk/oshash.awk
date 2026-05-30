# OpenSubtitles Hash (OSHash) - AWK implementation (gawk).
# Run with:  gawk -f oshash.awk <file>
#
# AWK has no binary I/O, so bytes are read via `od` (the same approach the Bash
# port uses). AWK numbers are IEEE doubles, so the hash is kept as four 16-bit
# words with explicit carry -- never as a full uint64 double, which would lose
# precision past 2^53. The file size is read as hex (shell printf renders it
# exactly) and parsed nibble-by-nibble, so even a multi-exabyte size is exact.

function add64(acc, val,    i, s, carry) {
    carry = 0
    for (i = 0; i < 4; i++) {
        s = acc[i] + val[i] + carry
        acc[i] = s % 65536
        carry = (s >= 65536) ? 1 : 0
    }
}

# Parse up to 4 hex digits into an exact integer (0..65535).
function hexval(s,    i, d, v) {
    v = 0
    for (i = 1; i <= length(s); i++) {
        d = index("0123456789abcdef", tolower(substr(s, i, 1))) - 1
        v = v * 16 + d
    }
    return v
}

# Sum a 64 KB region produced by `cmd` (an od pipeline) into the hash, reading
# it as little-endian unsigned 64-bit integers.
function sum_region(cmd, hash,    line, b, word, n) {
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

    # File size as 16 exact hex digits (shell printf handles the full uint64).
    cmd = "printf '%016x' \"$(stat -c%s '" file "')\""
    cmd | getline sizehex
    close(cmd)
    szword[3] = hexval(substr(sizehex, 1, 4))
    szword[2] = hexval(substr(sizehex, 5, 4))
    szword[1] = hexval(substr(sizehex, 9, 4))
    szword[0] = hexval(substr(sizehex, 13, 4))
    add64(hash, szword)

    # First and last 64 KB via head/tail (no large byte offsets to mishandle).
    sum_region("head -c 65536 '" file "' | od -An -v -t u1 -w8", hash)
    sum_region("tail -c 65536 '" file "' | od -An -v -t u1 -w8", hash)

    printf "%04x%04x%04x%04x\n", hash[3], hash[2], hash[1], hash[0]
}
