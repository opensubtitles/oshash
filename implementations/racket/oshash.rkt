#lang racket/base
;; OpenSubtitles Hash (OSHash) - Racket implementation.
;; hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB).
;; Racket integers are arbitrary precision, so the total is masked to 64 bits.
(require racket/format)

(define (sum-le bs)
  (define len (bytes-length bs))
  (let loop ([i 0] [acc 0])
    (if (> (+ i 8) len)
        acc
        (let ([w (for/fold ([w 0]) ([j (in-range 8)])
                   (+ w (arithmetic-shift (bytes-ref bs (+ i j)) (* 8 j))))])
          (loop (+ i 8) (+ acc w))))))

(define args (current-command-line-arguments))
(when (zero? (vector-length args))
  (eprintf "Usage: oshash <file>\n")
  (exit 1))

(define path (vector-ref args 0))
(define size (file-size path))
(define in (open-input-file path))
(define first-chunk (read-bytes 65536 in))
(file-position in (max 0 (- size 65536)))
(define last-chunk (read-bytes 65536 in))
(close-input-port in)

(define mask (- (expt 2 64) 1))
(define hash (bitwise-and (+ size (sum-le first-chunk) (sum-le last-chunk)) mask))
(printf "~a\n" (~r hash #:base 16 #:min-width 16 #:pad-string "0"))
