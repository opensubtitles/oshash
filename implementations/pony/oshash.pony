// OpenSubtitles Hash (OSHash) - Pony implementation.
// hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB).
// Pony's U64 arithmetic wraps modulo 2^64; File.seek_start reaches the last
// 64 KB without streaming the file.
use "files"

actor Main
  new create(env: Env) =>
    env.exitcode(run(env))

  fun run(env: Env): I32 =>
    try
      let path = env.args(1)?
      let fp = FilePath(FileAuth(env.root), path)
      let info = FileInfo(fp)?
      let size = info.size
      let file = File.open(fp)
      let first: Array[U8] val = file.read(65536)
      let lastoff: USize = if size > 65536 then size - 65536 else 0 end
      file.seek_start(lastoff)
      let last: Array[U8] val = file.read(65536)
      file.dispose()
      let hash: U64 = size.u64() + sum_le(first) + sum_le(last)
      env.out.print(hex16(hash))
      0
    else
      env.err.print("Usage: oshash <file>")
      1
    end

  fun hex16(v: U64): String =>
    let digits = "0123456789abcdef"
    let out = recover String(16) end
    var shift: U64 = 64
    while shift > 0 do
      shift = shift - 4
      try out.push(digits(((v >> shift) and 0xF).usize())?) end
    end
    consume out

  fun sum_le(b: Array[U8] val): U64 =>
    var s: U64 = 0
    var i: USize = 0
    while (i + 8) <= b.size() do
      var w: U64 = 0
      var j: USize = 0
      while j < 8 do
        try w = w + (b(i + j)?.u64() << (8 * j).u64()) end
        j = j + 1
      end
      s = s + w
      i = i + 8
    end
    s
