// OpenSubtitles Hash (OSHash) - Scala implementation.
import java.io.{FileInputStream, File}
import java.nio.{LongBuffer, ByteOrder, ByteBuffer}
import java.nio.channels.FileChannel.MapMode
import scala.math._

object OSHash {
    private val hashChunkSize = 64L * 1024L

    def computeHash(file: File): String = {
        val fileSize = file.length
        val chunkSizeForFile = min(fileSize, hashChunkSize)
        val fileChannel = new FileInputStream(file).getChannel

        try {
            val head = computeHashForChunk(
                fileChannel.map(MapMode.READ_ONLY, 0, chunkSizeForFile))
            val tail = computeHashForChunk(
                fileChannel.map(MapMode.READ_ONLY, max(fileSize - hashChunkSize, 0), chunkSizeForFile))
            "%016x".format(fileSize + head + tail)
        } finally {
            fileChannel.close()
        }
    }

    private def computeHashForChunk(buffer: ByteBuffer): Long = {
        val longBuffer = buffer.order(ByteOrder.LITTLE_ENDIAN).asLongBuffer()
        var hash = 0L
        while (longBuffer.hasRemaining) {
            hash += longBuffer.get
        }
        hash
    }

    def main(args: Array[String]): Unit = {
        if (args.length < 1) {
            System.err.println("Usage: scala OSHash <file>")
            sys.exit(1)
        }
        println(computeHash(new File(args(0))))
    }
}
