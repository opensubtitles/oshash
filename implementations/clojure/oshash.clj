;; OpenSubtitles Hash (OSHash) - Clojure implementation.
;; Algorithm: file_size + sum_le_u64(first_64KB) + sum_le_u64(last_64KB)

(import '[java.io RandomAccessFile]
        '[java.nio ByteBuffer ByteOrder])

(def chunk-size 65536)

(defn compute-hash [filepath]
  (let [raf (RandomAccessFile. filepath "r")
        fsize (.length raf)
        buf (byte-array chunk-size)]
    ;; Read first 64KB
    (.seek raf 0)
    (.readFully raf buf)
    (let [bb1 (-> (ByteBuffer/wrap buf) (.order ByteOrder/LITTLE_ENDIAN) .asLongBuffer)
          head (loop [i 0 h 0]
                 (if (< i (/ chunk-size 8))
                   (recur (inc i) (unchecked-add h (.get bb1)))
                   h))
          ;; Read last 64KB
          _ (.seek raf (max 0 (- fsize chunk-size)))
          _ (.readFully raf buf)
          bb2 (-> (ByteBuffer/wrap buf) (.order ByteOrder/LITTLE_ENDIAN) .asLongBuffer)
          tail (loop [i 0 h 0]
                 (if (< i (/ chunk-size 8))
                   (recur (inc i) (unchecked-add h (.get bb2)))
                   h))]
      (.close raf)
      (format "%016x" (unchecked-add fsize (unchecked-add head tail))))))

(when-let [filepath (first *command-line-args*)]
  (println (compute-hash filepath)))
