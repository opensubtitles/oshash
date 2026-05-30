; OpenSubtitles Hash (OSHash) - Scheme implementation (Gambit).
; hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB).
; Scheme integers are arbitrary precision, so the running total is masked back
; to 64 bits with `mask`.
;
; Gambit's input-port-byte-position can't seek past 2^32, so rather than seeking
; we read the first 64 KB directly and obtain the last 64 KB via `tail -c`
; (which handles multi-GB offsets) -- the same shell-out approach the Bash and
; AWK ports use for byte access.

(define chunk 65536)
(define mask (- (expt 2 64) 1))

; Sum the first `len` bytes of a u8vector as little-endian unsigned 64-bit.
(define (sum-region u8 len)
  (let loop ((i 0) (acc 0))
    (if (> (+ i 8) len)
        acc
        (let wloop ((j 0) (w 0))
          (if (= j 8)
              (loop (+ i 8) (bitwise-and (+ acc w) mask))
              (wloop (+ j 1)
                     (+ w (arithmetic-shift (u8vector-ref u8 (+ i j)) (* 8 j)))))))))

; Read up to n bytes from a port into v, looping until filled or EOF.
(define (read-fully port v n)
  (let loop ((off 0))
    (if (>= off n)
        off
        (let ((r (read-subu8vector v off n port)))
          (if (= r 0) off (loop (+ off r)))))))

(define (pad16 s)
  (string-append (make-string (max 0 (- 16 (string-length s))) #\0) s))

(define (oshash path)
  (let* ((size  (file-info-size (file-info path)))
         (fp    (open-input-file (list path: path)))
         (first (make-u8vector chunk 0))
         (n1    (read-fully fp first chunk))
         (tp    (open-input-process
                  (list path: "tail"
                        arguments: (list "-c" (number->string chunk) path)
                        stdout-redirection: #t)))
         (last  (make-u8vector chunk 0))
         (n2    (read-fully tp last chunk)))
    (close-input-port fp)
    (close-input-port tp)
    (bitwise-and (+ size (sum-region first n1) (sum-region last n2)) mask)))

(define (main)
  (let ((args (cdr (command-line))))
    (if (null? args)
        (begin (display "Usage: oshash <file>\n" (current-error-port)) (exit 1))
        (begin
          (display (pad16 (number->string (oshash (car args)) 16)))
          (newline)))))

(main)
