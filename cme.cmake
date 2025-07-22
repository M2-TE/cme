cmake_minimum_required(VERSION 3.25)

# set up the locations for generated files
set(CME_SOURCES_DIR "${CMAKE_CURRENT_BINARY_DIR}/cme/src")
set(CME_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/cme/include")

function(cme_create_library CME_NAME)
    set(args_option STATIC SHARED C CXX)
    set(args_single BASE_DIR NAMESPACE)
    cmake_parse_arguments(CME "${args_option}" "${args_single}" "" "${ARGN}")

    # CME_* arg error handling
    if (DEFINED CME_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "CME: Unknown arguments (${CME_UNPARSED_ARGUMENTS})")
    endif()

    # Arg: library type
    if (CME_STATIC AND CME_SHARED)
        message(FATAL_ERROR "CME: Asset library cannot be both STATIC and SHARED")
    elseif (CME_STATIC)
        set(CME_TYPE STATIC)
    elseif (DEFINED CME_SHARED)
        set(CME_TYPE SHARED)
    endif()

    # Arg: enabled languages
    if (NOT CME_C AND NOT CME_CXX)
        set(CME_CXX ON)
    endif()

    # Arg: asset library name
    set(CME_VALID_CHARS "^[a-zA-Z_][a-zA-Z0-9_]*[^!-\/:-@[-`{-~]$")
    if (NOT ${CME_NAME} MATCHES ${CME_VALID_CHARS})
        message(FATAL_ERROR "CME: Library name (${CME_NAME}) contains invalid characters")
    endif()
    set(CME_NAME ${CME_NAME})

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

    # execute custom command, running this .cmake script with set variables
    # creates cme_* and cme::* libraries with dependency on generated source file
    if (CME_C AND CME_CXX)
            set(CME_C_SOURCE_FILE   "${CME_SOURCES_DIR}/cme_${CME_NAME}.c")
            set(CME_C_HEADER_FILE   "${CME_INCLUDE_DIR}/cme/${CME_NAME}.h")
            set(CME_CXX_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cpp")
            set(CME_CXX_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.hpp")
        add_custom_command(
            OUTPUT  ${CME_C_SOURCE_FILE} ${CME_C_HEADER_FILE} ${CME_CXX_SOURCE_FILE} ${CME_CXX_HEADER_FILE}
            DEPENDS ${CME_ASSET_FILES}
            COMMAND ${CMAKE_COMMAND} -DCME_NAME=${CME_NAME} -DCME_TYPE=${CME_TYPE} -DCME_C=${CME_C} -DCME_CXX=${CME_CXX} -DCME_BASE_DIR=${CME_BASE_DIR} -P ${CMAKE_CURRENT_SOURCE_DIR}/cme.cmake
            COMMENT "Generating C and C++ asset library cme::${CME_NAME}"
            ${CME_CODEGEN_ARG})
        add_library(cme_${CME_NAME} ${CME_TYPE} ${CME_C_SOURCE_FILE} ${CME_CXX_SOURCE_FILE})
    elseif (CME_C)
        set(CME_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.c")
        set(CME_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.h")
        add_custom_command(
            OUTPUT  ${CME_SOURCE_FILE} ${CME_HEADER_FILE}
            DEPENDS ${CME_ASSET_FILES}
            COMMAND ${CMAKE_COMMAND} -DCME_NAME=${CME_NAME} -DCME_TYPE=${CME_TYPE} -DCME_C=${CME_C} -DCME_BASE_DIR=${CME_BASE_DIR} -P ${CMAKE_CURRENT_SOURCE_DIR}/cme.cmake
            COMMENT "Generating C asset library cme::${CME_NAME}"
            ${CME_CODEGEN_ARG})
        add_library(cme_${CME_NAME} ${CME_TYPE} ${CME_SOURCE_FILE})
    elseif (CME_CXX)
        set(CME_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cpp")
        set(CME_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.hpp")
        add_custom_command(
            OUTPUT  ${CME_SOURCE_FILE} ${CME_HEADER_FILE}
            DEPENDS ${CME_ASSET_FILES}
            COMMAND ${CMAKE_COMMAND} -DCME_NAME=${CME_NAME} -DCME_TYPE=${CME_TYPE} -DCME_CXX=${CME_CXX} -DCME_BASE_DIR=${CME_BASE_DIR} -P ${CMAKE_CURRENT_SOURCE_DIR}/cme.cmake
            COMMENT "Generating C++ asset library cme::${CME_NAME}"
            ${CME_CODEGEN_ARG})
        add_library(cme_${CME_NAME} ${CME_TYPE} ${CME_SOURCE_FILE})
    endif()

    if (CME_C)
        # enforce C23 for #embed
        target_compile_features(cme_${CME_NAME} PRIVATE c_std_23)
    endif()
    if (CME_CXX)
        # enforce C++14 for frozen
        target_compile_features(cme_${CME_NAME} PRIVATE cxx_std_14)

        # suppress warnings about #embed being a C23 extension
        if (MSVC)
            target_compile_options(cme_${CME_NAME} PRIVATE "/W0") # TODO: there should be a specific flag for it
        else()
            target_compile_options(cme_${CME_NAME} PRIVATE "-Wno-c23-extensions")
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
        target_include_directories(cme_${CME_NAME} SYSTEM PRIVATE "${frozen_SOURCE_DIR}/include")
    endif()

    # finalize library target
    add_library(cme::${CME_NAME} ALIAS cme_${CME_NAME})
    target_include_directories(cme_${CME_NAME} PUBLIC ${CME_INCLUDE_DIR})
endfunction()

# if script was run by cme_create_library(), create the asset library files
if ((DEFINED CME_NAME) AND (CME_TYPE STREQUAL "STATIC" OR CME_TYPE STREQUAL "SHARED") AND (CME_C OR CME_CXX) AND (DEFINED CME_BASE_DIR))
    # work in an isolated space
    block()
        set(CME_C_SOURCE_FILE   "${CME_SOURCES_DIR}/cme_${CME_NAME}.c")
        set(CME_C_HEADER_FILE   "${CME_INCLUDE_DIR}/cme/${CME_NAME}.h")
        set(CME_CXX_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cpp")
        set(CME_CXX_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.hpp")

        # create the header and source files
        if (CME_C)
            file(MAKE_DIRECTORY "${CME_INCLUDE_DIR}/cme")
            file(WRITE ${CME_C_SOURCE_FILE} "#include <stdint.h>\n")
            file(WRITE ${CME_C_HEADER_FILE} "#pragma once\n#include <stdint.h>\n")
        endif()
        if (CME_CXX)
            # .cpp
            file(WRITE ${CME_CXX_SOURCE_FILE} "#include <frozen/unordered_map.h>\n")
            file(APPEND ${CME_CXX_SOURCE_FILE} "#include <frozen/string.h>\n")
            file(APPEND ${CME_CXX_SOURCE_FILE} "#include <cme/${CME_NAME}.hpp>\n")
            file(APPEND ${CME_CXX_SOURCE_FILE} "\nnamespace ${CME_NAME} {\n")
            # .hpp
            file(WRITE ${CME_CXX_HEADER_FILE} 
"#pragma once
#include <cstdint>
#include <string_view>

namespace ${CME_NAME} {
    struct Asset {
        // TODO: ALIGNMENT??
        // TODO: span?

        // get data as array of T instead of uint8
        template<typename T>
        auto get() -> std::pair<T*, uint64_t> {
            const T* data = reinterpret_cast<const T*>(_data);
            const uint64_t size = _size / sizeof(T);
            return { data, size };
        }

        const uint8_t* _data;
        const uint64_t _size;
    };

    // load an embedded asset
    auto load(const std::string_view path) -> Asset;
    // load an embedded asset if it exists
    auto try_load(const std::string_view path) noexcept -> std::pair<Asset, bool>;
    // check if the path points to an embedded asset
    auto exists(const std::string_view path) noexcept -> bool;
}\n")
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

        # add lookup map entry to C++ source
        if (CME_CXX)
            list(LENGTH CME_ASSET_FILES CME_ASSET_FILES_COUNT)
            file(APPEND ${CME_CXX_SOURCE_FILE} "\n\tconstexpr frozen::unordered_map<frozen::string, Asset, ${CME_ASSET_FILES_COUNT}> asset_map = {\n")
            foreach (ASSET_PATH_FULL ${CME_ASSET_FILES})
                # get shortened path relative to shader directory root
                cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
                # replace illegal characters for C var names
                string(MAKE_C_IDENTIFIER ${ASSET_PATH_RELATIVE} ASSET_NAME)
                file(APPEND ${CME_CXX_SOURCE_FILE} "\t\t{\"${ASSET_PATH_RELATIVE}\", {${ASSET_NAME}, ${ASSET_NAME}_size}},\n")
            endforeach()

            # finalize the source file
            file(APPEND ${CME_CXX_SOURCE_FILE}
"\t};

    auto load(const std::string_view path) -> Asset {
        return asset_map.at(path);
    }
    auto try_load(const std::string_view path) noexcept -> std::pair<Asset, bool> {
        auto it = asset_map.find(path);
        if (it == asset_map.cend()) return {{}, false};
        else return { it->second, true };
    }
    auto exists(const std::string_view path) noexcept -> bool {
        return asset_map.contains(path);
    }
}\n")
        endif()

    endblock()
endif()