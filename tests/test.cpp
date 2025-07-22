#include <iostream>
#include "cme/cxx_assets.hpp"

int main() {
    auto asset = cxx_assets::load("subfolder/stuff.txt");
    std::cout << asset._size << std::endl;
    return 0;
}