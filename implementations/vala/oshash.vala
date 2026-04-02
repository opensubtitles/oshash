// OpenSubtitles Hash (OSHash) - Vala implementation.

public uint64 compute_hash(File file) {
    try {
        uint64 h;

        var file_info = file.query_info("*", FileQueryInfoFlags.NONE);
        h = (uint64)file_info.get_size();

        var dis = new DataInputStream(file.read());
        dis.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);
        for (int i = 0; i < 65536 / (int)sizeof(uint64); i++) {
            h += dis.read_uint64();
        }

        dis = new DataInputStream(file.read());
        dis.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);
        dis.skip((size_t)(file_info.get_size() - 65536));
        for (int i = 0; i < 65536 / (int)sizeof(uint64); i++) {
            h += dis.read_uint64();
        }

        return h;
    } catch (Error e) {
        error("%s", e.message);
    }
}

int main(string[] args) {
    if (args.length < 2) {
        stderr.printf("Usage: %s <file>\n", args[0]);
        return 1;
    }

    var file = File.new_for_path(args[1]);
    if (!file.query_exists()) {
        stderr.printf("File '%s' doesn't exist.\n", file.get_path());
        return 1;
    }
    stdout.printf("%016" + uint64.FORMAT_MODIFIER + "x\n", compute_hash(file));
    return 0;
}
