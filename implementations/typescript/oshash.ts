#!/usr/bin/env node
/**
 * OpenSubtitles Hash (OSHash) - TypeScript implementation.
 * Requires Node.js with BigInt support (v10.3+).
 */
import * as fs from 'fs';

const CHUNK_SIZE = 65536;

function computeHash(filepath: string): string {
    const fd = fs.openSync(filepath, 'r');
    const { size: filesize } = fs.fstatSync(fd);

    if (filesize < CHUNK_SIZE * 2) {
        fs.closeSync(fd);
        throw new Error(`File too small: ${filesize} bytes`);
    }

    let hash = BigInt(filesize);
    const buf = Buffer.alloc(8);

    // Hash first 64KB
    for (let i = 0; i < CHUNK_SIZE / 8; i++) {
        fs.readSync(fd, buf, 0, 8, i * 8);
        hash = (hash + buf.readBigUInt64LE(0)) & 0xFFFFFFFFFFFFFFFFn;
    }

    // Hash last 64KB
    const tailOffset = Math.max(0, filesize - CHUNK_SIZE);
    for (let i = 0; i < CHUNK_SIZE / 8; i++) {
        fs.readSync(fd, buf, 0, 8, tailOffset + i * 8);
        hash = (hash + buf.readBigUInt64LE(0)) & 0xFFFFFFFFFFFFFFFFn;
    }

    fs.closeSync(fd);
    return hash.toString(16).padStart(16, '0');
}

const filepath = process.argv[2];
if (!filepath) {
    console.error(`Usage: ${process.argv[1]} <file>`);
    process.exit(1);
}

console.log(computeHash(filepath));
