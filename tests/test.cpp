#include <iostream>
#include "cme/cme.hpp"

int main() {
    auto asset = cme::load("subfolder/stuff.txt");
    std::cout << asset._size << std::endl;
    return 0;
}