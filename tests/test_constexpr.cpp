#include <iostream>
#include "cme/cxx_constexpr.hpp"

int main() {
    static constexpr auto asset = cxx_constexpr::load("subfolder/stuff.txt");
    std::cout << asset._size << std::endl;
    return 0;
}