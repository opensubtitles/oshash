(* OpenSubtitles Hash (OSHash) - Modula-2 implementation (GNU Modula-2).
   hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB).
   The hash is kept as four 16-bit words with explicit carry (CARDINAL is only
   guaranteed wide enough for that), and FIO.SetPositionFromBeginning seeks to
   the last 64 KB. *)

MODULE oshash;

FROM Args IMPORT GetArg, Narg;
FROM FIO IMPORT File, OpenToRead, Close, ReadNBytes, StdOut, WriteChar,
                SetPositionFromBeginning, SetPositionFromEnd, FindPosition;
FROM SYSTEM IMPORT ADR;

CONST Chunk = 65536;

TYPE Words = ARRAY [0..3] OF CARDINAL;

VAR
  path : ARRAY [0..1023] OF CHAR;
  buf  : ARRAY [0..Chunk-1] OF CHAR;
  hash : Words;
  f    : File;
  size : LONGINT;
  got  : CARDINAL;
  i    : CARDINAL;

PROCEDURE Add4 (VAR h: Words; v: Words);
VAR i, s, carry: CARDINAL;
BEGIN
  carry := 0;
  FOR i := 0 TO 3 DO
    s := h[i] + v[i] + carry;
    h[i] := s MOD 65536;
    carry := s DIV 65536
  END
END Add4;

(* sum the first n bytes of buf as little-endian unsigned 64-bit words *)
PROCEDURE SumRegion (n: CARDINAL);
VAR i, b, base: CARDINAL; w: Words;
BEGIN
  i := 0;
  WHILE i + 8 <= n DO
    base := i;
    w[0] := ORD(buf[base+0]) + ORD(buf[base+1]) * 256;
    w[1] := ORD(buf[base+2]) + ORD(buf[base+3]) * 256;
    w[2] := ORD(buf[base+4]) + ORD(buf[base+5]) * 256;
    w[3] := ORD(buf[base+6]) + ORD(buf[base+7]) * 256;
    Add4(hash, w);
    i := i + 8
  END
END SumRegion;

PROCEDURE SizeWords (s: LONGINT; VAR w: Words);
VAR i: CARDINAL; sz: LONGINT;
BEGIN
  sz := s;
  FOR i := 0 TO 3 DO
    w[i] := VAL(CARDINAL, sz MOD 65536);
    sz := sz DIV 65536
  END
END SizeWords;

PROCEDURE WriteHex4 (w: CARDINAL);
VAR i: CARDINAL; div: ARRAY [0..3] OF CARDINAL; digits: ARRAY [0..16] OF CHAR;
BEGIN
  digits := "0123456789abcdef";
  div[0] := 4096; div[1] := 256; div[2] := 16; div[3] := 1;   (* MSB first *)
  FOR i := 0 TO 3 DO
    WriteChar(StdOut, digits[(w DIV div[i]) MOD 16])
  END
END WriteHex4;

VAR sw: Words;
BEGIN
  IF Narg() < 2 THEN
    HALT
  END;
  IF NOT GetArg(path, 1) THEN HALT END;

  FOR i := 0 TO 3 DO hash[i] := 0 END;

  f := OpenToRead(path);
  SetPositionFromEnd(f, 0);
  size := FindPosition(f);

  SetPositionFromBeginning(f, 0);
  got := ReadNBytes(f, Chunk, ADR(buf));
  SumRegion(got);

  IF size > VAL(LONGINT, Chunk) THEN
    SetPositionFromBeginning(f, size - VAL(LONGINT, Chunk))
  ELSE
    SetPositionFromBeginning(f, 0)
  END;
  got := ReadNBytes(f, Chunk, ADR(buf));
  SumRegion(got);
  Close(f);

  SizeWords(size, sw);
  Add4(hash, sw);

  WriteHex4(hash[3]); WriteHex4(hash[2]); WriteHex4(hash[1]); WriteHex4(hash[0]);
  WriteChar(StdOut, CHR(10))
END oshash.
