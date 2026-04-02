// OpenSubtitles Hash (OSHash) - Zig implementation.
// Algorithm: file_size + sum_le_u64(first_64KB) + sum_le_u64(last_64KB)
const std = @import("std");

const CHUNK_SIZE: usize = 65536;

fn computeHash(path: []const u8) !u64 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const fsize: u64 = stat.size;

    var hash: u64 = fsize;

    // Read first 64KB
    var buf: [CHUNK_SIZE]u8 = undefined;
    const head_bytes = try file.readAll(&buf);
    _ = head_bytes;
    const head_longs = std.mem.bytesAsSlice(u64, buf[0..CHUNK_SIZE]);
    for (head_longs) |val| {
        hash +%= std.mem.littleToNative(u64, val);
    }

    // Read last 64KB
    try file.seekTo(fsize - CHUNK_SIZE);
    _ = try file.readAll(&buf);
    const tail_longs = std.mem.bytesAsSlice(u64, buf[0..CHUNK_SIZE]);
    for (tail_longs) |val| {
        hash +%= std.mem.littleToNative(u64, val);
    }

    return hash;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: oshash <file>\n", .{});
        std.process.exit(1);
    }

    const hash = try computeHash(args[1]);
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{x:0>16}\n", .{hash});
}
