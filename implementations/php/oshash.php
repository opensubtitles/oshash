#!/usr/bin/env php
<?php
/**
 * OpenSubtitles Hash (OSHash) - PHP implementation.
 * Uses 16-bit chunk arithmetic to avoid 64-bit overflow issues.
 */

function computeHash(string $file): string {
    $handle = fopen($file, "rb");
    if (!$handle) throw new Exception("Cannot open file: $file");

    $fsize = filesize($file);
    if ($fsize < 65536 * 2) throw new Exception("File too small: $fsize bytes");

    $hash = [
        3 => 0,
        2 => 0,
        1 => ($fsize >> 16) & 0xFFFF,
        0 => $fsize & 0xFFFF
    ];

    for ($i = 0; $i < 8192; $i++) {
        $tmp = readUINT64($handle);
        $hash = addUINT64($hash, $tmp);
    }

    $offset = $fsize - 65536;
    fseek($handle, $offset > 0 ? $offset : 0, SEEK_SET);

    for ($i = 0; $i < 8192; $i++) {
        $tmp = readUINT64($handle);
        $hash = addUINT64($hash, $tmp);
    }

    fclose($handle);
    return UINT64FormatHex($hash);
}

function readUINT64($handle): array {
    $u = unpack("va/vb/vc/vd", fread($handle, 8));
    return [0 => $u["a"], 1 => $u["b"], 2 => $u["c"], 3 => $u["d"]];
}

function addUINT64(array $a, array $b): array {
    $o = [0 => 0, 1 => 0, 2 => 0, 3 => 0];
    $carry = 0;
    for ($i = 0; $i < 4; $i++) {
        $sum = $a[$i] + $b[$i] + $carry;
        if ($sum > 0xFFFF) {
            $o[$i] = $sum & 0xFFFF;
            $carry = 1;
        } else {
            $o[$i] = $sum;
            $carry = 0;
        }
    }
    return $o;
}

function UINT64FormatHex(array $n): string {
    return sprintf("%04x%04x%04x%04x", $n[3], $n[2], $n[1], $n[0]);
}

if ($argc < 2) {
    fwrite(STDERR, "Usage: php oshash.php <file>\n");
    exit(1);
}

echo computeHash($argv[1]) . "\n";
