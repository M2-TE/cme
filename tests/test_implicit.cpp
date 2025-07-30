#include <iostream>
#include "cme/cxx_assets_implicit.hpp"

int main() {
    auto asset = cxx_assets_implicit::load("subfolder/stuff.txt");
    auto asset2 = cxx_assets_implicit::load("subfolder/morestuff.txt");
    std::cout << asset._size << ' ' << asset2._size << std::endl;
    return 0;
}