#!/usr/bin/env Rscript
# OpenSubtitles Hash (OSHash) - R implementation.
# Uses split 32-bit arithmetic to handle 64-bit values.

CHUNK_SIZE <- 65536L

hex4 <- function(val) {
  # Convert 0-65535 to 4-char hex
  h <- format(as.hexmode(as.integer(val)))
  paste0(paste(rep("0", 4 - nchar(h)), collapse = ""), h)
}

to_hex8 <- function(val) {
  val <- floor(val) %% (2^32)
  paste0(hex4(floor(val / 65536)), hex4(val %% 65536))
}

compute_hash <- function(filepath) {
  fsize <- file.info(filepath)$size
  if (fsize < CHUNK_SIZE * 2) stop(paste("File too small:", fsize, "bytes"))

  con <- file(filepath, "rb")
  on.exit(close(con))

  # Split into hi/lo 32-bit halves
  lo <- fsize %% (2^32)
  hi <- floor(fsize / (2^32))

  add_to_hash <- function(bytes8) {
    v_lo <- as.numeric(bytes8[1]) + as.numeric(bytes8[2]) * 256 +
            as.numeric(bytes8[3]) * 65536 + as.numeric(bytes8[4]) * 16777216
    v_hi <- as.numeric(bytes8[5]) + as.numeric(bytes8[6]) * 256 +
            as.numeric(bytes8[7]) * 65536 + as.numeric(bytes8[8]) * 16777216

    lo <<- lo + v_lo
    hi <<- hi + v_hi

    if (lo >= 2^32) {
      hi <<- hi + floor(lo / 2^32)
      lo <<- lo %% 2^32
    }
    if (hi >= 2^32) {
      hi <<- hi %% 2^32
    }
  }

  # Hash first 64KB
  for (i in seq_len(8192)) {
    bytes8 <- readBin(con, "raw", n = 8)
    add_to_hash(bytes8)
  }

  # Hash last 64KB
  seek(con, max(0, fsize - CHUNK_SIZE))
  for (i in seq_len(8192)) {
    bytes8 <- readBin(con, "raw", n = 8)
    add_to_hash(bytes8)
  }

  paste0(to_hex8(hi), to_hex8(lo))
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  cat("Usage: Rscript oshash.R <file>\n", file = stderr())
  quit(status = 1)
}

cat(compute_hash(args[1]), "\n")
