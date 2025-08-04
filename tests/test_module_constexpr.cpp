#include <iostream>
import cme.cxx_module_assets_constexpr;

int main() {
    static constexpr auto asset1 = cxx_module_assets_constexpr::load("subfolder/stuff.txt");
    static constexpr auto asset2 = cxx_module_assets_constexpr::load("subfolder/morestuff.txt");
    std::cout << asset1._size << ' ' << asset2._size << std::endl;
    return 0;
}