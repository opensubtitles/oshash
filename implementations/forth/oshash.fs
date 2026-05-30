\ OpenSubtitles Hash (OSHash) - Forth implementation (gforth).
\ hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB).
\ Forth cells are 64-bit here and addition wraps naturally; REPOSITION-FILE
\ seeks to the last 64 KB without streaming the file.

65536 constant CHUNK
create BUF CHUNK allot
variable OSACC
variable FID
create HEXBUF 16 allot

\ assemble 8 little-endian bytes at addr into a 64-bit unsigned cell
: u64@le ( addr -- u )
  0 8 0 do
    over i + c@   ( addr acc byte )
    i 3 lshift lshift  ( addr acc byte<<8i )
    +
  loop nip ;

\ add the little-endian uint64 sum of the first n bytes of BUF to OSACC
: sum-region ( n -- )
  8 / 0 ?do
    BUF i 8 * + u64@le OSACC +!
  loop ;

: nibble>char ( n -- c )
  dup 10 < if [char] 0 + else 10 - [char] a + then ;

: .hash ( u -- )   \ 16 lowercase hex digits, MSB first
  16 0 do
    dup  15 i - 4 *  rshift  15 and  nibble>char
    HEXBUF i + c!
  loop drop
  HEXBUF 16 type cr ;

: oshash ( c-addr u -- u )
  r/o open-file throw FID !
  OSACC off
  \ first 64 KB
  0. FID @ reposition-file throw
  BUF CHUNK FID @ read-file throw  sum-region
  \ file size (low cell is enough for any real file)
  FID @ file-size throw drop  ( size )  dup OSACC +!
  \ last 64 KB
  CHUNK - dup 0< if drop 0 then  ( lastoff )
  s>d FID @ reposition-file throw
  BUF CHUNK FID @ read-file throw  sum-region
  FID @ close-file throw
  OSACC @ ;

: main
  next-arg dup 0= if
    2drop ." Usage: oshash <file>" cr 1 (bye)
  then
  oshash .hash
  bye ;

main
