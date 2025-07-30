#include <iostream>
#include "cme/cxx_constexpr.hpp"

int main() {
    static constexpr auto asset = cxx_constexpr::load("subfolder/stuff.txt");
    static constexpr auto asset2 = cxx_constexpr::load("subfolder/morestuff.txt");
    std::cout << asset._size << ' ' << asset2._size << std::endl;
    return 0;
}