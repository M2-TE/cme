#include <iostream>
#include "cme/both_assets.hpp"

int main() {
    auto asset = both_assets::load("subfolder/stuff.txt");
    std::cout << asset._size << std::endl;
    return 0;
}