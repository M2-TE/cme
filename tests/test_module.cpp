#include <iostream>
import cme.cxx_module_assets;

int main() {
    auto asset1 = cxx_module_assets::load("subfolder/stuff.txt");
    auto asset2 = cxx_module_assets::load("subfolder/morestuff.txt");
    std::cout << asset1._size << ' ' << asset2._size << std::endl;
    return 0;
}