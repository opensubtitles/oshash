// OpenSubtitles Hash (OSHash) - Dart implementation.
import 'dart:io';
import 'dart:typed_data';

const chunkSize = 65536;

String computeHash(String filepath) {
  final file = File(filepath);
  final raf = file.openSync(mode: FileMode.read);
  final filesize = file.lengthSync();

  if (filesize < chunkSize * 2) {
    raf.closeSync();
    throw Exception('File too small: $filesize bytes');
  }

  // Use wrapping arithmetic via masking
  int hash = filesize;

  // Hash first 64KB
  final headBytes = Uint8List.fromList(raf.readSync(chunkSize));
  final headData = ByteData.sublistView(headBytes);
  for (var i = 0; i < chunkSize ~/ 8; i++) {
    // Read as signed int64 LE (Dart int is signed 64-bit)
    hash += headData.getInt64(i * 8, Endian.little);
  }

  // Hash last 64KB
  raf.setPositionSync(filesize - chunkSize);
  final tailBytes = Uint8List.fromList(raf.readSync(chunkSize));
  final tailData = ByteData.sublistView(tailBytes);
  for (var i = 0; i < chunkSize ~/ 8; i++) {
    hash += tailData.getInt64(i * 8, Endian.little);
  }

  raf.closeSync();

  // Convert to unsigned hex representation
  // Dart int wraps at 64 bits, so just mask and format
  int unsigned = hash;
  if (unsigned < 0) {
    // Convert negative signed to unsigned equivalent via BigInt
    BigInt big = BigInt.from(hash).toUnsigned(64);
    return big.toRadixString(16).padLeft(16, '0');
  }
  return unsigned.toRadixString(16).padLeft(16, '0');
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart oshash.dart <file>');
    exit(1);
  }
  print(computeHash(args[0]));
}
