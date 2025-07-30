cmake_minimum_required(VERSION 3.25)

# set up the locations for generated files
set(CME_SOURCES_DIR "${CMAKE_CURRENT_BINARY_DIR}/cme/src")
set(CME_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/cme/include")

# main function to create a new asset library
# possible args with <default>:
# [<STATIC>, SHARED, CONSTEXPR]
# [C, <CXX>, CXX_MODULE]
# [BASE_DIR "path/to/dir"]
function(cme_create_library CME_NAME)
    set(args_option STATIC SHARED CONSTEXPR C CXX CXX_MODULE)
    set(args_single BASE_DIR)
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

    # Arg: library type [STATIC, SHARED]
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
        set(CME_TYPE STATIC)
    endif()

    # Arg: enabled languages [C, CXX, CXX_MODULE]
    if (CME_C AND CME_CXX)
        message(FATAL_ERROR "CME: asset library cannot be both C and CXX")
    elseif(CME_C)
        set(CME_LANGUAGE C)
    elseif(CME_CXX)
        set(CME_LANGUAGE CXX)
    elseif(CME_CXX_MODULE)
        set(CME_LANGUAGE CXX_MODULE)
    else()
        set(CME_LANGUAGE CXX) # default
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
    if (CME_C)
        set(CME_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.h")
        set(CME_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.c")
        add_custom_command(
            OUTPUT  ${CME_SOURCE_FILE} ${CME_HEADER_FILE}
            DEPENDS ${CME_ASSET_FILES}
            COMMAND ${CMAKE_COMMAND}
                -DCME_NAME=${CME_NAME}
                -DCME_TYPE=${CME_TYPE}
                -DCME_LANGUAGE=${CME_LANGUAGE}
                -DCME_BASE_DIR=${CME_BASE_DIR}
                -P ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cme.cmake
            COMMENT "Generating C asset library cme::${CME_NAME}"
            ${CME_CODEGEN_ARG})
        add_library(cme_${CME_NAME} ${CME_TYPE} ${CME_SOURCE_FILE})
    elseif (CME_CXX)
        set(CME_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.hpp")
        set(CME_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cpp")
        add_custom_command(
            OUTPUT  ${CME_SOURCE_FILE} ${CME_HEADER_FILE}
            DEPENDS ${CME_ASSET_FILES}
            COMMAND ${CMAKE_COMMAND}
                -DCME_NAME=${CME_NAME}
                -DCME_TYPE=${CME_TYPE}
                -DCME_LANGUAGE=${CME_LANGUAGE}
                -DCME_BASE_DIR=${CME_BASE_DIR}
                -P ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cme.cmake
            COMMENT "Generating C++ asset library cme::${CME_NAME}"
            ${CME_CODEGEN_ARG})
        add_library(cme_${CME_NAME} ${CME_TYPE} ${CME_SOURCE_FILE})
    endif()

    # scope needs to be INTERFACE when CONSTEXPR is used
    if (CME_CONSTEXPR)
        set(CME_LIBRARY_SCOPE INTERFACE)
        set(CME_INCLUDE_SCOPE INTERFACE)
    else()
        set(CME_LIBRARY_SCOPE PRIVATE)
        set(CME_INCLUDE_SCOPE PUBLIC)
    endif()

    # target settings
    if (CME_C)
        # enforce C23 for #embed
        target_compile_features(cme_${CME_NAME} ${CME_LIBRARY_SCOPE} c_std_23)
    elseif (CME_CXX)
        # enforce C++14 for frozen
        target_compile_features(cme_${CME_NAME} ${CME_LIBRARY_SCOPE} cxx_std_14)

        # suppress warnings about #embed being a C23 extension
        if (MSVC)
            target_compile_options(cme_${CME_NAME} ${CME_LIBRARY_SCOPE} "/W0") # TODO: there should be a specific flag for it
        else()
            target_compile_options(cme_${CME_NAME} ${CME_LIBRARY_SCOPE} "-Wno-c23-extensions")
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
        target_include_directories(cme_${CME_NAME} SYSTEM ${CME_LIBRARY_SCOPE} "${frozen_SOURCE_DIR}/include")
    endif()

    # finalize library target
    target_include_directories(cme_${CME_NAME} ${CME_INCLUDE_SCOPE} ${CME_INCLUDE_DIR})
    add_library(cme::${CME_NAME} ALIAS cme_${CME_NAME})
endfunction()

# isolated code generator block
block()
    if (CME_TYPE STREQUAL "INTERFACE")
        set(CME_CONSTEXPR ON)
    endif()
    if     (CME_LANGUAGE STREQUAL C)
        set(CME_C_FILE     "${CME_SOURCES_DIR}/cme_${CME_NAME}.c")
        set(CME_H_FILE     "${CME_INCLUDE_DIR}/cme/${CME_NAME}.h")
        seT(CME_ASSET_FILE "${CME_INCLUDE_DIR}/cme/detail/asset.h")

        # asset.h header that will be shared by all C asset libs
        if (NOT EXISTS ${CME_ASSET_FILE})
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}#pragma once\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}#include <stdint.h>\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}struct Asset {\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}    const uint8_t* _data;\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}    const uint64_t _size;\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}};\n")
            file(WRITE ${CME_ASSET_FILE} "${CME_ASSET_FILE_STRING}")
        endif()

        # {name}.c
        file(WRITE ${CME_C_FILE} "#include <cme/detail/asset.h>\n\n")
        # {name}.h
        file(WRITE  ${CME_H_FILE} "#pragma once\n")
        if (CME_CONSTEXPR)
            file(APPEND ${CME_H_FILE} "#include <${CME_C_FILE}>\n\n")
        else()
            file(APPEND ${CME_H_FILE} "#include <cme/detail/asset.h>\n\n")
        endif()

        # append #embed entries to header/source files
        file(GLOB_RECURSE CME_ASSET_FILES "${CME_BASE_DIR}/*")
        foreach (ASSET_PATH_FULL ${CME_ASSET_FILES})
            # get shortened path relative to shader directory root
            cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
            # replace illegal characters for C var names
            string(MAKE_C_IDENTIFIER ${ASSET_PATH_RELATIVE} ASSET_NAME)

            # add definition to C source
            file(APPEND ${CME_C_FILE} "const uint8_t  ${ASSET_NAME}[] = {\n\t#embed \"${ASSET_PATH_FULL}\"\n};\n")
            file(APPEND ${CME_C_FILE} "const uint64_t ${ASSET_NAME}_size = sizeof ${ASSET_NAME};\n")
            # add declaration to C header
            if (CME_CONSTEXPR)
                file(APPEND ${CME_H_FILE} "const uint8_t ${ASSET_NAME}[];\n")
                file(APPEND ${CME_H_FILE} "const uint64_t ${ASSET_NAME}_size;\n")
            else()
                file(APPEND ${CME_H_FILE} "extern const uint8_t* ${ASSET_NAME};\n")
                file(APPEND ${CME_H_FILE} "extern const uint64_t ${ASSET_NAME}_size;\n")
            endif()
        endforeach()

    elseif (CME_LANGUAGE STREQUAL CXX)
        set(CME_CPP_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cpp")
        set(CME_HPP_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.hpp")
        set(CME_ASSET_FILE "${CME_INCLUDE_DIR}/cme/detail/asset.hpp")

        # asset.hpp header that will be shared by all C++ asset libs
        if (NOT EXISTS ${CME_ASSET_FILE})
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}#pragma once\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}#include <cstdint>\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}#include <utility>\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}namespace cme {\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}    struct Asset {\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}        // get data as array of T instead of uint8\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}        template<typename T>\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}        auto get() -> std::pair<T*, uint64_t> const {\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}            const T* data = reinterpret_cast<const T*>(_data);\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}            const uint64_t size = _size / sizeof(T);\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}            return { data, size };\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}        }\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}        const uint8_t* _data;\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}        const uint64_t _size;\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}    };\n")
            set(CME_ASSET_FILE_STRING "${CME_ASSET_FILE_STRING}}\n")
            file(WRITE  ${CME_ASSET_FILE} "${CME_ASSET_FILE_STRING}")
        endif()

        # {name}.hpp
        if (CME_CONSTEXPR)
            set(CME_CXX_SOURCE_INCLUSION "#include <${CME_CPP_FILE}>\n")
            set(CME_CONSTEXPR_KEYWORD "constexpr")
        endif()
        file(WRITE  ${CME_HPP_FILE} "#pragma once\n")
        file(APPEND ${CME_HPP_FILE} "#include <string_view>\n")
        file(APPEND ${CME_HPP_FILE} "#include <cme/detail/asset.hpp>\n")
        file(APPEND ${CME_HPP_FILE} "${CME_CXX_SOURCE_INCLUSION}\n")
        file(APPEND ${CME_HPP_FILE} "namespace ${CME_NAME} {\n")
        file(APPEND ${CME_HPP_FILE} "    // load an embedded asset\n")
        file(APPEND ${CME_HPP_FILE} "    auto ${CME_CONSTEXPR_KEYWORD} load(const std::string_view path) -> cme::Asset;\n")
        file(APPEND ${CME_HPP_FILE} "    // load an embedded asset if it exists\n")
        file(APPEND ${CME_HPP_FILE} "    auto ${CME_CONSTEXPR_KEYWORD} try_load(const std::string_view path) noexcept -> std::pair<cme::Asset, bool>;\n")
        file(APPEND ${CME_HPP_FILE} "    // check if the path points to an embedded asset\n")
        file(APPEND ${CME_HPP_FILE} "    auto ${CME_CONSTEXPR_KEYWORD} exists(const std::string_view path) noexcept -> bool;\n")
        file(APPEND ${CME_HPP_FILE} "}\n")
        
        # {name}.cpp
        file(WRITE  ${CME_CPP_FILE} "#include <frozen/unordered_map.h>\n")
        file(APPEND ${CME_CPP_FILE} "#include <frozen/string.h>\n")
        file(APPEND ${CME_CPP_FILE} "#include <cme/detail/asset.hpp>\n")
        file(APPEND ${CME_CPP_FILE} "\nnamespace ${CME_NAME} {\n")

        # append #embed entries to the C++ files
        file(GLOB_RECURSE CME_ASSET_FILES "${CME_BASE_DIR}/*")
        foreach (ASSET_PATH_FULL ${CME_ASSET_FILES})
            # get shortened path relative to shader directory root
            cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
            # replace illegal characters to suit C var name (replace with "_" for the most part)
            string(MAKE_C_IDENTIFIER ${ASSET_PATH_RELATIVE} ASSET_NAME)

            # add definition to C++ source
            file(APPEND ${CME_CPP_FILE} "\tstatic constexpr uint8_t  ${ASSET_NAME}[] = {\n\t\t#embed \"${ASSET_PATH_FULL}\"\n\t};\n")
            file(APPEND ${CME_CPP_FILE} "\tstatic constexpr uint64_t ${ASSET_NAME}_size = sizeof ${ASSET_NAME};\n")
        endforeach()

        # build lookup map in {name}.cpp
        list(LENGTH CME_ASSET_FILES CME_ASSET_FILES_COUNT)
        file(APPEND ${CME_CPP_FILE} "\n\tconstexpr frozen::unordered_map<frozen::string, cme::Asset, ${CME_ASSET_FILES_COUNT}> asset_map = {\n")
        foreach (ASSET_PATH_FULL ${CME_ASSET_FILES})
            # get shortened path relative to shader directory root
            cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
            # replace illegal characters for C var names
            string(MAKE_C_IDENTIFIER ${ASSET_PATH_RELATIVE} ASSET_NAME)

            # add lookup entry
            file(APPEND ${CME_CPP_FILE} "\t\t{\"${ASSET_PATH_RELATIVE}\", {${ASSET_NAME}, ${ASSET_NAME}_size}},\n")
        endforeach()
        
        # finalize {name}.cpp
        file(APPEND ${CME_CPP_FILE} "\t};\n\n")
        file(APPEND ${CME_CPP_FILE} "    auto ${CME_CONSTEXPR_KEYWORD} load(const std::string_view path) -> cme::Asset {\n")
        file(APPEND ${CME_CPP_FILE} "        return asset_map.at(path);\n")
        file(APPEND ${CME_CPP_FILE} "    }\n")
        file(APPEND ${CME_CPP_FILE} "    auto ${CME_CONSTEXPR_KEYWORD} try_load(const std::string_view path) noexcept -> std::pair<cme::Asset, bool> {\n")
        file(APPEND ${CME_CPP_FILE} "        auto it = asset_map.find(path);\n")
        file(APPEND ${CME_CPP_FILE} "        if (it == asset_map.cend()) return {{}, false};\n")
        file(APPEND ${CME_CPP_FILE} "        else return { it->second, true };\n")
        file(APPEND ${CME_CPP_FILE} "    }\n")
        file(APPEND ${CME_CPP_FILE} "    auto ${CME_CONSTEXPR_KEYWORD} exists(const std::string_view path) noexcept -> bool {\n")
        file(APPEND ${CME_CPP_FILE} "        return asset_map.contains(path);\n")
        file(APPEND ${CME_CPP_FILE} "    }\n")
        file(APPEND ${CME_CPP_FILE} "}\n")
    elseif (CME_LANGUAGE STREQUAL CME_CXX_MODULE)
        # TODO
    endif()
endblock()
