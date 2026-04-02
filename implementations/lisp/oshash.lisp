;;; OpenSubtitles Hash (OSHash) - Common Lisp implementation (SBCL).

(defun get-lvalue (stream)
  (let ((n 0) (m 1))
    (loop for x from 0 to 7 do
      (let ((c (read-byte stream)))
        (setf n (+ n (* c m)))
        (setf m (* m 256))))
    n))

(defun compute-hash (path)
  (with-open-file (in path :element-type '(unsigned-byte 8))
    (let* ((len (file-length in))
           (hash len))
      (when (< len (* 2 65536))
        (error "File too small: ~a bytes" len))

      ;; Hash first 64KB
      (loop for x from 0 to 8191 do
        (setf hash (logand (+ hash (get-lvalue in)) #xFFFFFFFFFFFFFFFF)))

      ;; Hash last 64KB
      (file-position in (- len 65536))
      (loop for x from 0 to 8191 do
        (setf hash (logand (+ hash (get-lvalue in)) #xFFFFFFFFFFFFFFFF)))

      (format nil "~16,'0x" hash))))

(let ((args (cdr sb-ext:*posix-argv*)))
  (if (null args)
      (progn
        (format *error-output* "Usage: sbcl --script oshash.lisp <file>~%")
        (sb-ext:exit :code 1))
      (format t "~a~%" (string-downcase (compute-hash (car args))))))
