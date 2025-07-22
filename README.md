# CMake Embedder
Single `cme.cmake` script that embeds all assets within a certain directory into a C/C++ library using the #embed directive, despite the latter currently lacking official implementation.
In C++, the assets can be loaded at runtime using relative paths, as if loading from disk.

## Getting Started
### C++ example
#### CMakeLists.txt
```cmake
FetchContent_Declare(cme
    GIT_REPOSITORY "https://github.com/M2-TE/cme.git"
    GIT_TAG "v1.0.0"
    GIT_SHALLOW ON)
FetchContent_MakeAvailable(cme)
cme_create_library(assets STATIC CXX BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/assets")
target_link_libraries(${PROJECT_NAME} PUBLIC cme::assets)
```
#### example.cpp
```cpp
#include "cme/assets.hpp"
int main() {
    cme::Asset asset = assets::load("subfolder/stuff.txt");
}
```

### C example
#### CMakeLists.txt
```cmake
FetchContent_Declare(cme
    GIT_REPOSITORY "https://github.com/M2-TE/cme.git"
    GIT_TAG "v1.0.0"
    GIT_SHALLOW ON)
FetchContent_MakeAvailable(cme)
cme_create_library(assets STATIC C BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/assets")
target_link_libraries(${PROJECT_NAME} PUBLIC cme::assets)
```
#### example.c
```cpp
#include "cme/assets.h"
int main() {
    // in C, there is no loading via paths. Asset in this example is: "subfolder/stuff.txt"
    uint8_t* data = subfolder_stuff_txt;
    uint64_t size = subfolder_stuff_txt_size;
}
```
