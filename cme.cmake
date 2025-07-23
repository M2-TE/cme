cmake_minimum_required(VERSION 3.25)

# set up the locations for generated files
set(CME_SOURCES_DIR "${CMAKE_CURRENT_BINARY_DIR}/cme/src")
set(CME_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/cme/include")

function(cme_create_library CME_NAME)
    set(args_option STATIC SHARED C CXX CONSTEXPR)
    set(args_single BASE_DIR NAMESPACE)
    cmake_parse_arguments(CME "${args_option}" "${args_single}" "" "${ARGN}")

    # CME_* arg error handling
    if (DEFINED CME_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "CME: Unknown arguments (${CME_UNPARSED_ARGUMENTS})")
    endif()

    # Arg: asset library name
    set(CME_VALID_CHARS "^[a-zA-Z_][a-zA-Z0-9_]*[^!-\/:-@[-`{-~]$")
    if (NOT ${CME_NAME} MATCHES ${CME_VALID_CHARS})
        message(FATAL_ERROR "CME: Library name (${CME_NAME}) contains invalid characters")
    endif()
    set(CME_NAME ${CME_NAME})

    # Arg: library type
    if ((CME_STATIC OR CME_SHARED) AND CME_CONSTEXPR)
        message(FATAL_ERROR "CME: CONSTEXPR asset library cannot be STATIC or SHARED")
    elseif (CME_STATIC AND CME_SHARED)
        message(FATAL_ERROR "CME: Asset library cannot be both STATIC and SHARED")
    elseif(CME_CONSTEXPR)
        set(CME_TYPE INTERFACE)
    elseif (CME_STATIC)
        set(CME_TYPE STATIC)
    elseif (CME_SHARED)
        set(CME_TYPE SHARED)
    else()
        # static by default when not CONSTEXPR
        set(CME_TYPE STATIC)
    endif()

    # Arg: constexpr
    if (CME_CONSTEXPR)
        set(CME_CONSTEXPR "constexpr")
    else()
        set(CME_CONSTEXPR "")
    endif()

    # Arg: enabled languages
    if (NOT CME_C AND NOT CME_CXX)
        # cxx by default
        set(CME_CXX ON)
    endif()

    # Arg: base asset directory
    if (NOT DEFINED CME_BASE_DIR)
        message(FATAL_ERROR "CME: Requires BASE_DIR")
    elseif(NOT EXISTS ${CME_BASE_DIR})
        message(FATAL_ERROR "CME: Invalid BASE_DIR (${CME_BASE_DIR})")
    endif()

    # need to glob all files before lib creation to build dependency graph
    file(GLOB_RECURSE CME_ASSET_FILES CONFIGURE_DEPENDS "${CME_BASE_DIR}/*")

    # check for CODEGEN support
    set(CME_CODEGEN_ARG "")
    if (CMAKE_VERSION GREATER_EQUAL "3.31")
        cmake_policy(SET CMP0171 NEW)
        set(CME_CODEGEN_ARG CODEGEN)
    endif()

    # execute custom command, running this cme.cmake script with set variables
    # creates cme_* and cme::* libraries with dependency on generated files
    if (CME_C AND CME_CXX)
            set(CME_C_SOURCE_FILE   "${CME_SOURCES_DIR}/cme_${CME_NAME}.c")
            set(CME_C_HEADER_FILE   "${CME_INCLUDE_DIR}/cme/${CME_NAME}.h")
            set(CME_CXX_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cpp")
            set(CME_CXX_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.hpp")
        add_custom_command(
            OUTPUT  ${CME_C_SOURCE_FILE} ${CME_C_HEADER_FILE} ${CME_CXX_SOURCE_FILE} ${CME_CXX_HEADER_FILE}
            DEPENDS ${CME_ASSET_FILES}
            COMMAND ${CMAKE_COMMAND} -DCME_NAME=${CME_NAME} -DCME_TYPE=${CME_TYPE} -DCME_C=${CME_C} -DCME_CXX=${CME_CXX} -DCME_CONSTEXPR=${CME_CONSTEXPR} -DCME_BASE_DIR=${CME_BASE_DIR} -P ${CMAKE_CURRENT_SOURCE_DIR}/cme.cmake
            COMMENT "Generating C and C++ asset library cme::${CME_NAME}"
            ${CME_CODEGEN_ARG})
        add_library(cme_${CME_NAME} ${CME_TYPE} ${CME_C_SOURCE_FILE} ${CME_CXX_SOURCE_FILE})
    elseif (CME_C)
        set(CME_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.c")
        set(CME_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.h")
        add_custom_command(
            OUTPUT  ${CME_SOURCE_FILE} ${CME_HEADER_FILE}
            DEPENDS ${CME_ASSET_FILES}
            COMMAND ${CMAKE_COMMAND} -DCME_NAME=${CME_NAME} -DCME_TYPE=${CME_TYPE} -DCME_C=${CME_C} -DCME_BASE_DIR=${CME_BASE_DIR} -DCME_CONSTEXPR=${CME_CONSTEXPR} -P ${CMAKE_CURRENT_SOURCE_DIR}/cme.cmake
            COMMENT "Generating C asset library cme::${CME_NAME}"
            ${CME_CODEGEN_ARG})
        add_library(cme_${CME_NAME} ${CME_TYPE} ${CME_SOURCE_FILE})
    elseif (CME_CXX)
        set(CME_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cpp")
        set(CME_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.hpp")
        add_custom_command(
            OUTPUT  ${CME_SOURCE_FILE} ${CME_HEADER_FILE}
            DEPENDS ${CME_ASSET_FILES}
            COMMAND ${CMAKE_COMMAND} -DCME_NAME=${CME_NAME} -DCME_TYPE=${CME_TYPE} -DCME_CXX=${CME_CXX} -DCME_BASE_DIR=${CME_BASE_DIR} -DCME_CONSTEXPR=${CME_CONSTEXPR} -P ${CMAKE_CURRENT_SOURCE_DIR}/cme.cmake
            COMMENT "Generating C++ asset library cme::${CME_NAME}"
            ${CME_CODEGEN_ARG})
        add_library(cme_${CME_NAME} ${CME_TYPE} ${CME_SOURCE_FILE})
    endif()

    # scope needs to be INTERFACE when CONSTEXPR is used
    if (CME_CONSTEXPR STREQUAL "constexpr")
        set(CME_SCOPE INTERFACE)
    else()
        set(CME_SCOPE PRIVATE)
    endif()

    # target settings
    if (CME_C)
        # enforce C23 for #embed
        target_compile_features(cme_${CME_NAME} ${CME_SCOPE} c_std_23)
    endif()
    if (CME_CXX)

        # enforce C++14 for frozen
        target_compile_features(cme_${CME_NAME} ${CME_SCOPE} cxx_std_14)

        # suppress warnings about #embed being a C23 extension
        if (MSVC)
            target_compile_options(cme_${CME_NAME} ${CME_SCOPE} "/W0") # TODO: there should be a specific flag for it
        else()
            target_compile_options(cme_${CME_NAME} ${CME_SCOPE} "-Wno-c23-extensions")
        endif()

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
        target_include_directories(cme_${CME_NAME} SYSTEM ${CME_SCOPE} "${frozen_SOURCE_DIR}/include")
    endif()

    # finalize library target
    if (CME_CONSTEXPR STREQUAL "constexpr")
        target_include_directories(cme_${CME_NAME} INTERFACE ${CME_INCLUDE_DIR})
    else()
        target_include_directories(cme_${CME_NAME} PUBLIC ${CME_INCLUDE_DIR})
    endif()
    add_library(cme::${CME_NAME} ALIAS cme_${CME_NAME})
endfunction()

# if script was run by cme_create_library(), create the asset library files
if ((DEFINED CME_NAME) AND (DEFINED CME_CONSTEXPR) AND (DEFINED CME_TYPE) AND (CME_C OR CME_CXX) AND (DEFINED CME_BASE_DIR))
    # work in an isolated space
    block()
        set(CME_C_SOURCE_FILE   "${CME_SOURCES_DIR}/cme_${CME_NAME}.c")
        set(CME_C_HEADER_FILE   "${CME_INCLUDE_DIR}/cme/${CME_NAME}.h")
        set(CME_CXX_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cpp")
        set(CME_CXX_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.hpp")

        # cme/detail/asset.h
        set(CME_ASSET_H
"#pragma once
#include <stdint.h>
struct Asset {
    const uint8_t* _data\;
    const uint64_t _size\;
}\;\n")
        # cme/detail/asset.hpp
        set(CME_ASSET_HPP
"#pragma once
#include <cstdint>
#include <utility>
namespace cme {
    struct Asset {
        // get data as array of T instead of uint8
        template<typename T>
        auto get() -> std::pair<T*, uint64_t> const {
            const T* data = reinterpret_cast<const T*>(_data)\;
            const uint64_t size = _size / sizeof(T)\;
            return { data, size }\;
        }

        const uint8_t* _data\;
        const uint64_t _size\;
    }\;
}\n")
        # cme/*.hpp
        set(CME_CXX_SOURCE_INCLUSION "")
        if (CME_CONSTEXPR STREQUAL "constexpr")
            set(CME_CXX_SOURCE_INCLUSION "#include <${CME_CXX_SOURCE_FILE}>\n") 
        endif()
        set(CME_HPP
"#pragma once
#include <string_view>
#include <cme/detail/asset.hpp>
${CME_CXX_SOURCE_INCLUSION}
namespace ${CME_NAME} {
    // load an embedded asset
    auto ${CME_CONSTEXPR} load(const std::string_view path) -> cme::Asset\;
    // load an embedded asset if it exists
    auto ${CME_CONSTEXPR} try_load(const std::string_view path) noexcept -> std::pair<cme::Asset, bool>\;
    // check if the path points to an embedded asset
    auto ${CME_CONSTEXPR} exists(const std::string_view path) noexcept -> bool\;
}\n")
        # src/*.cpp
        set(CME_CPP
"\t}\;

    auto ${CME_CONSTEXPR} load(const std::string_view path) -> cme::Asset {
        return asset_map.at(path)\;
    }
    auto ${CME_CONSTEXPR} try_load(const std::string_view path) noexcept -> std::pair<cme::Asset, bool> {
        auto it = asset_map.find(path)\;
        if (it == asset_map.cend()) return {{}, false}\;
        else return { it->second, true }\;
    }
    auto ${CME_CONSTEXPR} exists(const std::string_view path) noexcept -> bool {
        return asset_map.contains(path)\;
    }
}\n")
        # create the headers for the Asset struct (shared by all asset libs)
        if (CME_C   AND NOT EXISTS "${CME_INCLUDE_DIR}/cme/detail/asset.h")
            file(WRITE "${CME_INCLUDE_DIR}/cme/detail/asset.h" ${CME_ASSET_H})
        endif()
        if (CME_CXX AND NOT EXISTS "${CME_INCLUDE_DIR}/cme/detail/asset.hpp")
            file(WRITE "${CME_INCLUDE_DIR}/cme/detail/asset.hpp" ${CME_ASSET_HPP})
        endif()

        # create the header and source files
        if (CME_C)
            # *.c
            file(WRITE ${CME_C_SOURCE_FILE} "#include <cme/detail/asset.h>\n\n")
            # *.h
            file(WRITE ${CME_C_HEADER_FILE} "#pragma once\n#include <cme/detail/asset.h>\n\n")
            if (CME_CONSTEXPR STREQUAL "constexpr")
                file(WRITE ${CME_C_HEADER_FILE} "#include <${CME_C_SOURCE_FILE}>\n\n")
            endif()
        endif()
        if (CME_CXX)
            # *.cpp
            file(WRITE ${CME_CXX_SOURCE_FILE} "#include <frozen/unordered_map.h>\n")
            file(APPEND ${CME_CXX_SOURCE_FILE} "#include <frozen/string.h>\n")
            file(APPEND ${CME_CXX_SOURCE_FILE} "#include <cme/detail/asset.hpp>\n")
            file(APPEND ${CME_CXX_SOURCE_FILE} "\nnamespace ${CME_NAME} {\n")
            # *.hpp
            file(WRITE ${CME_CXX_HEADER_FILE} ${CME_HPP})
        endif()

        # append #embed entries to the C/C++ files
        file(GLOB_RECURSE CME_ASSET_FILES "${CME_BASE_DIR}/*")
        foreach (ASSET_PATH_FULL ${CME_ASSET_FILES})
            # get shortened path relative to shader directory root
            cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
            # replace illegal characters for C var names
            string(MAKE_C_IDENTIFIER ${ASSET_PATH_RELATIVE} ASSET_NAME)

            if (CME_C)
                # add definition to C source
                file(APPEND ${CME_C_SOURCE_FILE} "const uint8_t  ${ASSET_NAME}[] = {\n\t#embed \"${ASSET_PATH_FULL}\"\n};\n")
                file(APPEND ${CME_C_SOURCE_FILE} "const uint64_t ${ASSET_NAME}_size = sizeof ${ASSET_NAME};\n")
                # add declaration to C header
                file(APPEND ${CME_C_HEADER_FILE} "extern const uint8_t* ${ASSET_NAME};\n")
                file(APPEND ${CME_C_HEADER_FILE} "extern const uint64_t ${ASSET_NAME}_size;\n")
            endif()

            if (CME_CXX)
                # add definition to C++ source
                file(APPEND ${CME_CXX_SOURCE_FILE} "\tstatic constexpr uint8_t  ${ASSET_NAME}[] = {\n\t\t#embed \"${ASSET_PATH_FULL}\"\n\t};\n")
                file(APPEND ${CME_CXX_SOURCE_FILE} "\tstatic constexpr uint64_t ${ASSET_NAME}_size = sizeof ${ASSET_NAME};\n")
            endif()
        endforeach()

        # add map entry to C++ source
        if (CME_CXX)
            list(LENGTH CME_ASSET_FILES CME_ASSET_FILES_COUNT)
            file(APPEND ${CME_CXX_SOURCE_FILE} "\n\tconstexpr frozen::unordered_map<frozen::string, cme::Asset, ${CME_ASSET_FILES_COUNT}> asset_map = {\n")
            foreach (ASSET_PATH_FULL ${CME_ASSET_FILES})
                # get shortened path relative to shader directory root
                cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
                # replace illegal characters for C var names
                string(MAKE_C_IDENTIFIER ${ASSET_PATH_RELATIVE} ASSET_NAME)
                file(APPEND ${CME_CXX_SOURCE_FILE} "\t\t{\"${ASSET_PATH_RELATIVE}\", {${ASSET_NAME}, ${ASSET_NAME}_size}},\n")
            endforeach()

            # finalize the source file
            file(APPEND ${CME_CXX_SOURCE_FILE} ${CME_CPP})
        endif()

    endblock()
endif()