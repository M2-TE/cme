cmake_minimum_required(VERSION 3.25)
project(cme LANGUAGES C CXX)

# vast number of project options
option(CME_BUILD_TESTS "Enable both C and C++ tests" ${PROJECT_IS_TOP_LEVEL})
option(CME_BUILD_C "Build the C library for asset loading without path strings" OFF)
option(CME_BUILD_CPP "Build the C++ library for asset loading via path strings" ON)

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
cmake_path(GET CME_HEADER_DIR PARENT_PATH CME_HEADER_DIR)

# create the files in the cmake binary directory
if (CME_BUILD_C)
    file(MAKE_DIRECTORY "${CME_HEADER_DIR}/cme")
    file(WRITE ${CME_SOURCE_C} "#include <stdint.h>\n")
    file(WRITE ${CME_HEADER_C} "#pragma once\n#include <stdint.h>\n")
endif()
if (CME_BUILD_CPP)
    file(MAKE_DIRECTORY "${CME_HEADER_DIR}/cme")
    file(READ "snippets/cpp_beg" CME_SOURCE_CPP_BEG)
    file(WRITE  ${CME_SOURCE_CPP} ${CME_SOURCE_CPP_BEG})
    file(COPY_FILE "snippets/cme.hpp" ${CME_HEADER_CPP} ONLY_IF_DIFFERENT)
endif()

# append to the C header and source files per input asset
foreach (ASSET_PATH_FULL ${CME_ASSET_FILES})
    # get shortened path relative to shader directory root
    cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_ASSET_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
    # replace illegal characters for C var names
    string(REPLACE "/" "_" ASSET_NAME "${ASSET_PATH_RELATIVE}")
    string(REPLACE "." "_" ASSET_NAME "${ASSET_NAME}")

    if (CME_BUILD_C)
        # add definition to C source
        file(APPEND ${CME_SOURCE_C} "const uint8_t  ${ASSET_NAME}[] = {\n\t#embed \"${ASSET_PATH_FULL}\"\n};\n")
        file(APPEND ${CME_SOURCE_C} "const uint64_t ${ASSET_NAME}_size = sizeof ${ASSET_NAME};\n")
        # add declaration to C header
        file(APPEND ${CME_HEADER_C} "extern const uint8_t* ${ASSET_NAME};\n")
        file(APPEND ${CME_HEADER_C} "extern const uint64_t ${ASSET_NAME}_size;\n")
    endif()

    if (CME_BUILD_CPP)
        # add definition to C++ source
        file(APPEND ${CME_SOURCE_CPP} "\tstatic constexpr uint8_t  ${ASSET_NAME}[] = {\n\t\t#embed \"${ASSET_PATH_FULL}\"\n\t};\n")
        file(APPEND ${CME_SOURCE_CPP} "\tstatic constexpr uint64_t ${ASSET_NAME}_size = sizeof ${ASSET_NAME};\n")
        # add lookup map entry to C++ source
        # file(APPEND ${CME_SOURCE_CPP} "\t\t{\"${ASSET_PATH_RELATIVE}\", {${ASSET_NAME}, ${ASSET_NAME}_size}}\n")
    endif()
endforeach()

# add lookup map entry to C++ source
if (CME_BUILD_CPP)
    file(APPEND ${CME_SOURCE_CPP} "\n\tconstexpr frozen::unordered_map<frozen::string, Asset, ${CME_ASSET_FILES_COUNT}> asset_map = {\n")
    foreach (ASSET_PATH_FULL ${CME_ASSET_FILES})
        cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_ASSET_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
        string(REPLACE "/" "_" ASSET_NAME "${ASSET_PATH_RELATIVE}")
        string(REPLACE "." "_" ASSET_NAME "${ASSET_NAME}")
        file(APPEND ${CME_SOURCE_CPP} "\t\t{\"${ASSET_PATH_RELATIVE}\", {${ASSET_NAME}, ${ASSET_NAME}_size}}\n")
    endforeach()

    # finalize the source file
    file(READ "snippets/cpp_end" CME_SOURCE_CPP_END)
    file(APPEND ${CME_SOURCE_CPP} ${CME_SOURCE_CPP_END})
endif()

# create C library for storing the assets
if (CME_BUILD_C)
    add_library(cme_c SHARED ${CME_SOURCE_C})
    add_library(cme::c ALIAS cme_c)
    target_compile_features(cme_c PRIVATE c_std_23)
    target_include_directories(cme_c PUBLIC ${CME_HEADER_DIR})
    set_target_properties(cme_c PROPERTIES C_EXTENSIONS ON)
endif()

# create C++ library for convenient asset loading
if (CME_BUILD_CPP)
    # use frozen for perfect hashing
    find_package(frozen QUIET)
    if (NOT frozen_FOUND)
        include(FetchContent)
        FetchContent_Declare(frozen
            GIT_REPOSITORY "https://github.com/serge-sans-paille/frozen.git"
            GIT_TAG "1.2.0"
            GIT_SHALLOW ON
            SOURCE_SUBDIR "disabled")
        FetchContent_MakeAvailable(frozen)
    endif()
    
    # create library
    add_library(cme_cpp SHARED ${CME_SOURCE_CPP})
    add_library(cme::cpp ALIAS cme_cpp)
    target_compile_features(cme_cpp PRIVATE cxx_std_20)
    target_include_directories(cme_cpp SYSTEM PRIVATE "${frozen_SOURCE_DIR}/include")
    target_include_directories(cme_cpp PUBLIC ${CME_HEADER_DIR})
    
    # suppress warnings about #embed being a C extension
    if (MSVC)
        target_compile_options(cme_cpp PRIVATE "/W0") # TODO: there should be a specific flag for it
    else()
        target_compile_options(cme_cpp PRIVATE "-Wno-c23-extensions")
    endif()
endif()

# some WIP tests for dev purposes (for now at least)
if (CME_BUILD_TESTS)
    if (CME_BUILD_C)
        add_executable(test_c   "tests/test.c")
        target_link_libraries(test_c   PRIVATE cme::c)
    endif()

    if (CME_BUILD_CPP)
        add_executable(test_cpp "tests/test.cpp")
        target_link_libraries(test_cpp PRIVATE cme::cpp)
    endif()
endif()