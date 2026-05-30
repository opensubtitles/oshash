#!/usr/bin/rexx
/* OpenSubtitles Hash (OSHash) - Rexx implementation (Regina).
   hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB).
   Rexx arithmetic is arbitrary-precision decimal, so with enough `numeric
   digits` the uint64 values add directly and we take the result // 2**64. */

numeric digits 40
parse arg path

mask = 2 ** 64

/* charin/query-size truncate large offsets to 32 bits, so the size and the
   trailing 64 KB come from stat/tail (the shell-out the Bash/AWK ports use). */
cmd = 'stat -c%s "' || path || '" > /tmp/rexx_size'
address system cmd
size = strip(linein('/tmp/rexx_size'))
call stream '/tmp/rexx_size', 'c', 'close'

first = charin(path, 1, 65536)
call stream path, 'c', 'close'

cmd = 'tail -c 65536 "' || path || '" > /tmp/rexx_last'
address system cmd
last = charin('/tmp/rexx_last', 1, 65536)
call stream '/tmp/rexx_last', 'c', 'close'

hash = size
hash = sum_region(first, hash)
hash = sum_region(last, hash)
hash = hash // mask

say translate(d2x(hash, 16), 'abcdef', 'ABCDEF')
exit 0

sum_region: procedure expose mask
  parse arg buf, acc
  n = length(buf)
  i = 1
  do while (i + 7) <= n
    w = 0
    do b = 0 to 7
      w = w + c2d(substr(buf, i + b, 1)) * (256 ** b)
    end
    acc = (acc + w) // mask
    i = i + 8
  end
  return acc
