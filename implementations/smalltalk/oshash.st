"OpenSubtitles Hash (OSHash) - Smalltalk implementation (GNU Smalltalk).
 hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB).
 Smalltalk integers are arbitrary precision, so the running total is masked
 back to 64 bits with `mask`."

| path f size first last mask sum hash hex pad |
path := Smalltalk arguments first.
mask := (1 bitShift: 64) - 1.

f := FileStream open: path mode: FileStream read.
size := f size.
first := f next: 65536.
f position: ((size - 65536) max: 0).
last := f next: 65536.
f close.

"sum the bytes as little-endian unsigned 64-bit words; each character's
 value is its byte (0-255)"
sum := [:bytes | | s |
    s := 0.
    0 to: (bytes size // 8) - 1 do: [:i | | w |
        w := 0.
        0 to: 7 do: [:b | w := w + (((bytes at: (i * 8) + b + 1) value) bitShift: (8 * b)) ].
        s := (s + w) bitAnd: mask ].
    s ].

hash := (size + (sum value: first) + (sum value: last)) bitAnd: mask.
hex := (hash printString: 16) asLowercase.
pad := 16 - hex size.
pad > 0 ifTrue: [ hex := (String new: pad withAll: $0), hex ].
Transcript showCr: hex.
