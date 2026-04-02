# OpenSubtitles Hash (OSHash) - Nim implementation.
import os, strformat, strutils

const ChunkSize = 65536

proc computeHash(filepath: string): string =
  let fsize = getFileSize(filepath)
  if fsize < ChunkSize * 2:
    raise newException(ValueError, "File too small: " & $fsize & " bytes")

  var hash: uint64 = uint64(fsize)
  var f = open(filepath, fmRead)
  defer: f.close()

  var buf: array[8, uint8]

  # Hash first 64KB
  for i in 0 ..< (ChunkSize div 8):
    discard f.readBytes(buf, 0, 8)
    var val: uint64 = 0
    for j in 0..7:
      val = val or (uint64(buf[j]) shl (j * 8))
    hash = hash + val

  # Hash last 64KB
  f.setFilePos(max(0, fsize - ChunkSize))
  for i in 0 ..< (ChunkSize div 8):
    discard f.readBytes(buf, 0, 8)
    var val: uint64 = 0
    for j in 0..7:
      val = val or (uint64(buf[j]) shl (j * 8))
    hash = hash + val

  return toLowerAscii(fmt"{hash:016x}")

when isMainModule:
  let params = commandLineParams()
  if params.len < 1:
    stderr.writeLine("Usage: oshash <file>")
    quit(1)
  echo computeHash(params[0])
