# CMake Embedder
Single `cme.cmake` script that embeds all assets within a certain directory into a C/C++ library using the #embed directive, despite the latter currently lacking official implementation.
In C++, the assets can be loaded at runtime (default) or compile-time using relative paths with perfect hash lookup via [serge-sans-paille/frozen](https://github.com/serge-sans-paille/frozen).

Normally, the assets are placed into a library and thus compiled only once, but they can optionally be placed into the headers with `CONSTEXPR` to e.g. allow for compile-time programming or embedding into the source of your choice.

Works with `gcc 15+` and `Clang 19+` (`Clang 20+` for C++20-modules), earlier compiler versions probably won't recognize #embed. MSVC seems to lack C23 implementations, meaning it likely won't work just yet; just use Clang on Windows as well.

## Getting Started

### CMake
#### Minimal example using `FetchContent`:
```cmake
include(FetchContent)
FetchContent_Declare(cme
    GIT_REPOSITORY "https://github.com/M2-TE/cme.git"
    GIT_TAG "v1.2.0"
    GIT_SHALLOW ON)
FetchContent_MakeAvailable(cme)

cme_create_library(
    assets # name of your asset library (affects CMake target name and C++ namespace)
    STATIC # [STATIC, SHARED] # may only choose one, omit when using CONSTEXPR
    CXX    # [C, CXX]         # can use both simultaneously, CXX by default if omitted
    BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/assets") # directory containing all your assets
# asset library target will be cme:: and the name you have chosen
target_link_libraries(${your_library} PRIVATE cme::assets)
```

### C/C++

#### example.cpp
```cpp
// with CXX_MODULE
import cme.assets;
// with CXX
#include "cme/assets.hpp"

int main() {
    // "assets" used as the asset library name
    cme::Asset asset = assets::load("subfolder/stuff.txt");
    // with CONSTEXPR or INTERFACE:
    static constexpr cme::Asset sc_asset = assets::load("subfolder/stuff.txt");
}
```

#### example.c
```c
#include "cme/assets.h"
int main() {
    // "assets" used as the asset library name
    // asset in this example is: "subfolder/stuff.txt"
    uint8_t* data = subfolder_stuff_txt;
    uint64_t size = subfolder_stuff_txt_size;
}
```
