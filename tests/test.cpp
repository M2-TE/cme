#include <iostream>
#include "cme/cme.h"

#include <unordered_map>

namespace cme {
    struct Asset {
        const uint8_t* data;
        const uint64_t size;
    };
}
const std::unordered_map<std::string, cme::Asset> lookupmap = {
    {"patha", {subfolder_stuff_txt, subfolder_stuff_txt_size}},
};

int main() {
    std::cout << subfolder_stuff_txt_size << std::endl;
    return 0;
}