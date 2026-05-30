// OpenSubtitles Hash (OSHash) - Objective-C implementation.
// Uses the GNU runtime's lightweight Object root class (no Foundation), so the
// binary static-links libobjc and runs on the host with no Objective-C runtime
// installed. hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last
// 64KB); uint64_t arithmetic wraps modulo 2^64.

#define _FILE_OFFSET_BITS 64
#include <objc/Object.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define CHUNK 65536

@interface OSHasher : Object
{
    uint64_t hash;
}
- (id)reset;
- (void)add:(uint64_t)value;
- (void)addChunk:(const unsigned char *)buf length:(size_t)len;
- (uint64_t)value;
@end

@implementation OSHasher
- (id)reset { hash = 0; return self; }
- (void)add:(uint64_t)value { hash += value; }
- (void)addChunk:(const unsigned char *)buf length:(size_t)len
{
    for (size_t i = 0; i + 8 <= len; i += 8) {
        uint64_t w = 0;
        for (int b = 0; b < 8; b++)
            w |= (uint64_t)buf[i + b] << (8 * b);
        hash += w;  // wraps at 2^64
    }
}
- (uint64_t)value { return hash; }
@end

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "Usage: oshash <file>\n"); return 1; }

    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror("open"); return 1; }

    fseeko(f, 0, SEEK_END);
    int64_t size = (int64_t)ftello(f);

    unsigned char *first = malloc(CHUNK), *last = malloc(CHUNK);
    fseeko(f, 0, SEEK_SET);
    size_t n1 = fread(first, 1, CHUNK, f);
    int64_t lastpos = size > CHUNK ? size - CHUNK : 0;
    fseeko(f, lastpos, SEEK_SET);
    size_t n2 = fread(last, 1, CHUNK, f);
    fclose(f);

    OSHasher *h = class_createInstance(objc_getClass("OSHasher"), 0);
    [h reset];
    [h add:(uint64_t)size];
    [h addChunk:first length:n1];
    [h addChunk:last length:n2];
    printf("%016llx\n", (unsigned long long)[h value]);

    free(first);
    free(last);
    return 0;
}
