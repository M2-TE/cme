#pragma once
#include <string>
#include <cstdint>

namespace cme {
    struct Asset {
        const uint8_t* data;
        const uint64_t size;
    };
    
    // TODO: make constexpr?

    // load an embedded asset using a path relative to the configured base directory
    extern Asset load(const std::string& path);
    // check if the path points to an embedded asset
    extern bool exists(const std::string& path);
}
