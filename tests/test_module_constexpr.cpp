#include <iostream>
import cme.cxx_module_assets;

int main() {
    // with C++ modules, constexpr should always work, regardless of lib type
    static constexpr auto asset = cxx_module_assets::load("subfolder/stuff.txt");
    auto asset2 = cxx_module_assets::load("subfolder/morestuff.txt");
    std::cout << asset._size << ' ' << asset2._size << std::endl;
    return 0;
}