cmake_minimum_required(VERSION 3.25)
project(cme LANGUAGES C CXX)

# vast number of project options
option(CME_BUILD_TESTS "Enable both C and C++ tests" ${PROJECT_IS_TOP_LEVEL})
option(CME_BUILD_CPP "Build the C++ library for more convenient asset loading" ON)

# having CME_ASSET_BASE_DIR set is a requirement
if (PROJECT_IS_TOP_LEVEL)
    set(CME_ASSET_BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/assets")
elseif (NOT DEFINED CME_ASSET_BASE_DIR)
    message(FATAL_ERROR "CME_ASSET_BASE_DIR must be defined, set it to the base directory containing your assets")
endif()

# collect all asset directories and count them
file(GLOB_RECURSE CME_ASSET_FILES CONFIGURE_DEPENDS "${CME_ASSET_BASE_DIR}/*")
list(LENGTH CME_ASSET_FILES CME_ASSET_FILES_COUNT)

# set up path for the generated header and source pair
set(CME_SOURCE_C   "${CMAKE_CURRENT_BINARY_DIR}/cme/src/cme.c")
set(CME_HEADER_C   "${CMAKE_CURRENT_BINARY_DIR}/cme/include/cme/cme.h")
set(CME_SOURCE_CPP "${CMAKE_CURRENT_BINARY_DIR}/cme/src/cme.cpp")
set(CME_HEADER_CPP "${CMAKE_CURRENT_BINARY_DIR}/cme/include/cme/cme.hpp")
cmake_path(GET CME_HEADER_C PARENT_PATH CME_HEADER_DIR)
cmake_path(GET CME_HEADER_DIR  PARENT_PATH CME_HEADER_DIR)

# create the files in the cmake binary directory
file(WRITE ${CME_SOURCE_C} "#include <stdint.h>\n")
file(WRITE ${CME_HEADER_C} "#pragma once\n#include <stdint.h>\n")
if (CME_BUILD_CPP)
    file(READ "snippets/cpp_beg" CME_SOURCE_CPP_BEG)
    file(WRITE  ${CME_SOURCE_CPP} ${CME_SOURCE_CPP_BEG})
    file(APPEND ${CME_SOURCE_CPP} "\tconst frozen::unordered_map<frozen::string, Asset, ${CME_ASSET_FILES_COUNT}> asset_map = {\n")
    file(COPY_FILE "snippets/cme.hpp" ${CME_HEADER_CPP})
endif()

# append to the C header and source files per input asset
foreach (ASSET_FULL_PATH ${CME_ASSET_FILES})
    # get shortened path relative to shader directory root
    cmake_path(RELATIVE_PATH ASSET_FULL_PATH BASE_DIRECTORY ${CME_ASSET_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
    # replace illegal characters for C var names
    string(REPLACE "/" "_" ASSET_NAME "${ASSET_PATH_RELATIVE}")
    string(REPLACE "." "_" ASSET_NAME "${ASSET_NAME}")
    # add definition to C source
    file(APPEND ${CME_SOURCE_C} "const uint8_t  ${ASSET_NAME}[] = {\n\t#embed \"${ASSET_FULL_PATH}\"\n};\n")
    file(APPEND ${CME_SOURCE_C} "const uint64_t ${ASSET_NAME}_size = sizeof ${ASSET_NAME};\n")
    # add declaration to C header
    file(APPEND ${CME_HEADER_C} "extern const uint8_t* ${ASSET_NAME};\n")
    file(APPEND ${CME_HEADER_C} "extern const uint64_t ${ASSET_NAME}_size;\n")
    # add lookup map entry to C++ source
    if (CME_BUILD_CPP)
        file(APPEND ${CME_SOURCE_CPP} "\t\t{\"${ASSET_PATH_RELATIVE}\", {${ASSET_NAME}, ${ASSET_NAME}_size}}\n")
    endif()
endforeach()

# finalize the source files
file(READ "snippets/cpp_end" CME_SOURCE_CPP_END)
file(APPEND ${CME_SOURCE_CPP} ${CME_SOURCE_CPP_END})

# create C library for storing the assets
add_library(cme_c SHARED ${CME_SOURCE_C})
add_library(cme::c ALIAS cme_c)
target_compile_features(cme_c PRIVATE c_std_23)
target_include_directories(cme_c PUBLIC ${CME_HEADER_DIR})
set_target_properties(cme_c PROPERTIES C_EXTENSIONS ON)

# create C++ library for convenient asset loading
if (CME_BUILD_CPP)
    include(FetchContent)
    FetchContent_Declare(frozen
        GIT_REPOSITORY "https://github.com/serge-sans-paille/frozen.git"
        GIT_TAG "1.2.0"
        GIT_SHALLOW ON
        SOURCE_SUBDIR "disabled")
    FetchContent_MakeAvailable(frozen)
    add_library(cme_cpp STATIC ${CME_SOURCE_CPP})
    add_library(cme::cpp ALIAS cme_cpp)
    target_link_libraries(cme_cpp PUBLIC cme::c)
    target_compile_features(cme_cpp PRIVATE cxx_std_14)
    target_include_directories(cme_cpp SYSTEM PRIVATE "${frozen_SOURCE_DIR}/include")
endif()

if (CME_BUILD_TESTS)
    add_executable(test_c   "tests/test.c")
    add_executable(test_cpp "tests/test.cpp")
    target_link_libraries(test_c PRIVATE cme::c)
    target_link_libraries(test_cpp PRIVATE cme::cpp)
endif()