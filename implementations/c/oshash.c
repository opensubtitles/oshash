/*
 * OpenSubtitles Hash (OSHash) - C implementation.
 * Algorithm: file_size + uint64_le_sum(first_64KB) + uint64_le_sum(last_64KB)
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define CHUNK_SIZE 65536

uint64_t compute_hash(FILE *handle) {
    uint64_t hash, fsize;
    uint64_t tmp;
    int i;

    fseek(handle, 0, SEEK_END);
    fsize = ftell(handle);
    fseek(handle, 0, SEEK_SET);

    hash = fsize;

    for (i = 0; i < CHUNK_SIZE / sizeof(uint64_t); i++) {
        tmp = 0;
        if (fread(&tmp, sizeof(uint64_t), 1, handle) == 0) break;
        hash += tmp;
    }

    fseek(handle, (long)(fsize > CHUNK_SIZE ? fsize - CHUNK_SIZE : 0), SEEK_SET);

    for (i = 0; i < CHUNK_SIZE / sizeof(uint64_t); i++) {
        tmp = 0;
        if (fread(&tmp, sizeof(uint64_t), 1, handle) == 0) break;
        hash += tmp;
    }

    return hash;
}

int main(int argc, char *argv[]) {
    FILE *handle;
    uint64_t myhash;

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <file>\n", argv[0]);
        return 1;
    }

    handle = fopen(argv[1], "rb");
    if (!handle) {
        fprintf(stderr, "Error opening file: %s\n", argv[1]);
        return 1;
    }

    myhash = compute_hash(handle);
    printf("%016lx\n", myhash);

    fclose(handle);
    return 0;
}
