#include <iostream>
#include "cme/cxx_assets_explicit.hpp"

int main() {
    auto asset = cxx_assets_explicit::load("subfolder/stuff.txt");
    auto asset2 = cxx_assets_explicit::load("subfolder/morestuff.txt");
    std::cout << asset._size << ' ' << asset2._size << std::endl;
    return 0;
}