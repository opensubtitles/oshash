#!/usr/bin/env node
/**
 * OpenSubtitles Hash (OSHash) - Node.js implementation.
 */
const fs = require('fs');

const CHUNK_SIZE = 65536;

function computeHash(filepath) {
    const fd = fs.openSync(filepath, 'r');
    const stat = fs.fstatSync(fd);
    const filesize = stat.size;

    if (filesize < CHUNK_SIZE * 2) {
        fs.closeSync(fd);
        throw new Error(`File too small: ${filesize} bytes`);
    }

    // Use BigInt for 64-bit arithmetic
    let hash = BigInt(filesize);
    const buf = Buffer.alloc(8);

    // Hash first 64KB
    for (let i = 0; i < CHUNK_SIZE / 8; i++) {
        fs.readSync(fd, buf, 0, 8, i * 8);
        hash += buf.readBigUInt64LE(0);
        hash &= 0xFFFFFFFFFFFFFFFFn;
    }

    // Hash last 64KB
    const tailOffset = Math.max(0, filesize - CHUNK_SIZE);
    for (let i = 0; i < CHUNK_SIZE / 8; i++) {
        fs.readSync(fd, buf, 0, 8, tailOffset + i * 8);
        hash += buf.readBigUInt64LE(0);
        hash &= 0xFFFFFFFFFFFFFFFFn;
    }

    fs.closeSync(fd);
    return hash.toString(16).padStart(16, '0');
}

if (process.argv.length < 3) {
    console.error(`Usage: ${process.argv[1]} <file>`);
    process.exit(1);
}

console.log(computeHash(process.argv[2]));
