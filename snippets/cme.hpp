#pragma once
#include <cstdint>
#include <string_view>

namespace cme {
    struct Asset {
        // TODO: ALIGNMENT??
        // TODO: span?

        // get data as array of T instead of uint8
        template<typename T>
        auto get() -> std::pair<T*, uint64_t> {
            const T* data = reinterpret_cast<const T*>(_data);
            const uint64_t size = _size / sizeof(T);
            return { data, size };
        }

        const uint8_t* _data;
        const uint64_t _size;
    };

    // load an embedded asset
    auto load(const std::string_view path) -> Asset;
    // load an embedded asset if it exists
    auto try_load(const std::string_view path) noexcept -> std::pair<Asset, bool>;
    // check if the path points to an embedded asset
    auto exists(const std::string_view path) noexcept -> bool;
}
