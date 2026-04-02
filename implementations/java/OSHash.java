import java.io.*;
import java.nio.*;
import java.nio.channels.FileChannel;
import java.nio.channels.FileChannel.MapMode;

/**
 * OpenSubtitles Hash (OSHash) - Java implementation.
 */
public class OSHash {

    private static final int HASH_CHUNK_SIZE = 64 * 1024;

    public static String computeHash(File file) throws IOException {
        long size = file.length();
        long chunkSizeForFile = Math.min(HASH_CHUNK_SIZE, size);

        try (FileInputStream fis = new FileInputStream(file)) {
            FileChannel fileChannel = fis.getChannel();

            long head = computeHashForChunk(
                fileChannel.map(MapMode.READ_ONLY, 0, chunkSizeForFile));
            long tail = computeHashForChunk(
                fileChannel.map(MapMode.READ_ONLY, Math.max(size - HASH_CHUNK_SIZE, 0), chunkSizeForFile));

            return String.format("%016x", size + head + tail);
        }
    }

    private static long computeHashForChunk(ByteBuffer buffer) {
        LongBuffer longBuffer = buffer.order(ByteOrder.LITTLE_ENDIAN).asLongBuffer();
        long hash = 0;
        while (longBuffer.hasRemaining()) {
            hash += longBuffer.get();
        }
        return hash;
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.err.println("Usage: java OSHash <file>");
            System.exit(1);
        }
        System.out.println(computeHash(new File(args[0])));
    }
}
