// OpenSubtitles Hash (OSHash) - D implementation.
// Algorithm: file_size + sum_le_u64(first_64KB) + sum_le_u64(last_64KB)
import std.stdio;
import std.format;
import std.conv;

enum CHUNK_SIZE = 65536;

string computeHash(string filepath) {
    auto f = File(filepath, "rb");
    f.seek(0, SEEK_END);
    ulong fsize = f.tell();
    f.seek(0, SEEK_SET);

    ulong hash = fsize;

    // Hash first 64KB
    ubyte[CHUNK_SIZE] buf;
    f.rawRead(buf[]);
    auto longs = cast(ulong[])(buf[]);
    foreach (val; longs)
        hash += val;

    // Hash last 64KB
    f.seek(cast(long)(fsize - CHUNK_SIZE), SEEK_SET);
    f.rawRead(buf[]);
    longs = cast(ulong[])(buf[]);
    foreach (val; longs)
        hash += val;

    return format("%016x", hash);
}

void main(string[] args) {
    if (args.length < 2) {
        stderr.writeln("Usage: oshash <file>");
        return;
    }
    writeln(computeHash(args[1]));
}
