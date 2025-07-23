# CMake Embedder
Single `cme.cmake` script that embeds all assets within a certain directory into a C/C++ library using the #embed directive, despite the latter currently lacking official implementation.
In C++, the assets can be loaded at runtime (default) or compile-time using relative paths, as if loading from disk.

Tested with `gcc 15` and `Clang 20`, earlier compiler versions probably won't recognize #embed.

## Getting Started

### CMake
**Option A**: Copy-paste `cme.cmake` to your project and simply include it
```cmake
include("cme.cmake")
```
**Option B**: Use `FetchContent` to automatically add it to your project
```cmake
include(FetchContent)
FetchContent_Declare(cme
    GIT_REPOSITORY "https://github.com/M2-TE/cme.git"
    GIT_TAG "v1.0.0"
    GIT_SHALLOW ON)
FetchContent_MakeAvailable(cme)
```
Once included, simply use the `cme_create_library` function to create your asset library and link to it
```cmake
cme_create_library(
    assets # name of your asset library (affects CMake target name and C++ namespace)
    CONSTEXPR # allows compile-time loading of assets, but places data into the header
    STATIC # [STATIC, SHARED] # may only choose one
    CXX    # [C, CXX]         # can use both simultaneously, CXX by default if omitted
    BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/assets") # directory containing all your assets
target_link_libraries(your_library PRIVATE cme::assets) # target will be cme:: and the name you have chosen
```

### C/C++
#### example.cpp
```cpp
#include "cme/assets.hpp" // CXX flag always creates the *.hpp header and *.cpp source files
int main() {
    static constexpr cme::Asset asset = assets::load("subfolder/stuff.txt");
}
```
#### example.c
```cpp
#include "cme/assets.h" // C flag creates the *.h header and *.c source files
int main() {
    // in C, there is no loading via paths. Asset in this example is: "subfolder/stuff.txt"
    uint8_t* data = subfolder_stuff_txt;
    uint64_t size = subfolder_stuff_txt_size;
}
```
