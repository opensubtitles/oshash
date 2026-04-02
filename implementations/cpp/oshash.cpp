/*
 * OpenSubtitles Hash (OSHash) - C++ implementation.
 */
#include <iostream>
#include <fstream>
#include <iomanip>
#include <cstdint>
#include <algorithm>

#define CHUNK_SIZE 65536

uint64_t compute_hash(std::ifstream &f) {
    uint64_t hash, fsize;

    f.seekg(0, std::ios::end);
    fsize = f.tellg();
    f.seekg(0, std::ios::beg);

    hash = fsize;

    uint64_t tmp = 0;
    for (uint64_t i = 0; i < CHUNK_SIZE / sizeof(tmp) && f.read(reinterpret_cast<char*>(&tmp), sizeof(tmp)); i++) {
        hash += tmp;
        tmp = 0;
    }

    f.seekg(std::max<int64_t>(0, fsize - CHUNK_SIZE), std::ios::beg);
    tmp = 0;
    for (uint64_t i = 0; i < CHUNK_SIZE / sizeof(tmp) && f.read(reinterpret_cast<char*>(&tmp), sizeof(tmp)); i++) {
        hash += tmp;
        tmp = 0;
    }

    return hash;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <file>" << std::endl;
        return 1;
    }

    std::ifstream f(argv[1], std::ios::in | std::ios::binary);
    if (!f.is_open()) {
        std::cerr << "Error opening file" << std::endl;
        return 1;
    }

    uint64_t myhash = compute_hash(f);
    std::cout << std::setw(16) << std::setfill('0') << std::hex << myhash << std::endl;

    f.close();
    return 0;
}
