(* OpenSubtitles Hash (OSHash) - Standard ML implementation (Poly/ML).
   hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB).
   Word64 arithmetic wraps modulo 2^64. Poly/ML's Posix.IO.lseek misbehaves, so
   the trailing 64 KB is obtained with `tail -c` (the shell-out the Bash/AWK
   ports use), avoiding any seek. polyc calls `main` at runtime. *)

val chunk = 65536

(* Sum a byte vector as little-endian unsigned 64-bit words. *)
fun sumVec v =
  let
    val len = Word8Vector.length v
    fun byteAt i = Word64.fromInt (Word8.toInt (Word8Vector.sub (v, i)))
    fun word i =
      let
        fun sh (j, acc) =
          if j > 7 then acc
          else sh (j + 1, Word64.orb (acc, Word64.<< (byteAt (i + j), Word.fromInt (8 * j))))
      in sh (0, 0w0) end
    fun loop (i, acc) =
      if i + 8 > len then acc
      else loop (i + 8, Word64.+ (acc, word i))
  in loop (0, 0w0) end

fun main () =
  case CommandLine.arguments () of
    [path] =>
      let
        val size = OS.FileSys.fileSize path
        (* first 64 KB *)
        val s1 = BinIO.openIn path
        val first = BinIO.inputN (s1, chunk)
        val _ = BinIO.closeIn s1
        (* last 64 KB via tail, into a temp file we then read sequentially *)
        val tmp = OS.FileSys.tmpName ()
        val _ = OS.Process.system ("tail -c " ^ Int.toString chunk ^ " '" ^ path ^ "' > " ^ tmp)
        val s2 = BinIO.openIn tmp
        val last = BinIO.inputAll s2
        val _ = BinIO.closeIn s2
        val _ = OS.FileSys.remove tmp
        val sz = Word64.fromLargeInt (Position.toLarge size)
        val hash = Word64.+ (sz, Word64.+ (sumVec first, sumVec last))
        val hex = String.map Char.toLower (StringCvt.padLeft #"0" 16 (Word64.fmt StringCvt.HEX hash))
      in
        print (hex ^ "\n")
      end
  | _ => (TextIO.output (TextIO.stdErr, "Usage: oshash <file>\n");
          OS.Process.exit OS.Process.failure)
