cmake_minimum_required(VERSION 3.25)

# set up the locations for generated files
set(CME_SOURCES_DIR "${CMAKE_CURRENT_BINARY_DIR}/cme/src")
set(CME_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/cme/include")

# main function to create a new asset library with <default> args
# OPTIONAL [<STATIC>, SHARED, INTERFACE/CONSTEXPR]
# OPTIONAL [C, <CXX>, CXX_MODULE]
# REQUIRED [BASE_DIR "/path/to/dir"]
# OPTIONAL [FILES "/file/A" "/file/B"]
function(cme_create_library CME_NAME)
    set(args_option STATIC SHARED INTERFACE CONSTEXPR C CXX CXX_MODULE)
    set(args_single BASE_DIR)
    set(args_multi  FILES)
    cmake_parse_arguments(CME "${args_option}" "${args_single}" "${args_multi}" "${ARGN}")

    # CME_* arg error handling
    if (DEFINED CME_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "CME asset library ${CME_NAME} created with unknown arguments (${CME_UNPARSED_ARGUMENTS})")
    endif()

    # Arg: asset library name
    set(CME_VALID_CHARS "^[a-zA-Z_][a-zA-Z0-9_]*[^!-\/:-@[-`{-~]$")
    if (NOT ${CME_NAME} MATCHES ${CME_VALID_CHARS})
        message(FATAL_ERROR "CME asset library ${CME_NAME} contains invalid characters")
    endif()

    # Arg: library type
    if ((CME_STATIC AND CME_SHARED) OR (CME_STATIC AND (CME_INTERFACE OR CME_CONSTEXPR)) OR (CME_SHARED AND (CME_INTERFACE OR CME_CONSTEXPR)))
        message(FATAL_ERROR "CME asset library ${CME_NAME} can only be one of: STATIC, SHARED, INTERFACE/CONSTEXPR")
    elseif (CME_STATIC)
        set(CME_TYPE STATIC)
    elseif (CME_SHARED)
        set(CME_TYPE SHARED)
    elseif (CME_INTERFACE OR CME_CONSTEXPR)
        set(CME_TYPE INTERFACE)
    else()
        set(CME_TYPE STATIC) # default
    endif()

    # Arg: enabled languages
    if ((CME_C AND CME_CXX) OR (CME_C AND CME_CXX_MODULE) OR (CME_CXX AND CME_CXX_MODULE))
        message(FATAL_ERROR "CME asset library ${CME_NAME} can only be one of: C, CXX or CXX_MODULE")
    elseif (CME_C)
        set(CME_LANGUAGE C)
    elseif (CME_CXX)
        set(CME_LANGUAGE CXX)
    elseif (CME_CXX_MODULE)
        set(CME_LANGUAGE CXX_MODULE)
    else()
        set(CME_LANGUAGE CXX) # default
    endif()

    # Arg: asset files
    if (NOT DEFINED CME_BASE_DIR)
        message(FATAL_ERROR "CME asset library ${CME_NAME} requires a BASE_DIR")
    elseif (NOT EXISTS ${CME_BASE_DIR})
        message(FATAL_ERROR "CME asset library ${CME_NAME} given an invalid BASE_DIR (${CME_BASE_DIR})")
    elseif (DEFINED CME_FILES)
        # only explicitly pass all the files when provided
        set(CME_EXPLICIT_FILE_PARAM -DCME_FILES="${CME_FILES}")
    else()
        # otherwise we just use file globbing
        file(GLOB_RECURSE CME_FILES CONFIGURE_DEPENDS "${CME_BASE_DIR}/*")
    endif()

    # check for CODEGEN support
    set(CME_CODEGEN_ARG "")
    if (CMAKE_VERSION GREATER_EQUAL "3.31")
        cmake_policy(SET CMP0171 NEW)
        set(CME_CODEGEN_ARG CODEGEN)
    endif()

    # add custom command, which will run this cme.cmake script with set variables
    # creates cme_* and cme::* libraries with dependencies on generated files
    set(CME_PARAMS
        -DCME_NAME="${CME_NAME}"
        -DCME_TYPE="${CME_TYPE}"
        -DCME_LANGUAGE="${CME_LANGUAGE}"
        -DCME_BASE_DIR="${CME_BASE_DIR}"
        ${CME_EXPLICIT_FILE_PARAM}
        -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cme.cmake")
    if (CME_C)
        set(CME_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.h")
        set(CME_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.c")
        add_custom_command(
            OUTPUT  ${CME_SOURCE_FILE} ${CME_HEADER_FILE}
            DEPENDS ${CME_FILES}
            COMMAND ${CMAKE_COMMAND} ${CME_PARAMS}
            COMMENT "Generating C asset library cme::${CME_NAME}"
            ${CME_CODEGEN_ARG})
        add_library(cme_${CME_NAME} ${CME_TYPE} ${CME_SOURCE_FILE})
    elseif (CME_CXX)
        set(CME_HEADER_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.hpp")
        set(CME_SOURCE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cpp")
        add_custom_command(
            OUTPUT  ${CME_SOURCE_FILE} ${CME_HEADER_FILE}
            DEPENDS ${CME_FILES}
            COMMAND ${CMAKE_COMMAND} ${CME_PARAMS}
            COMMENT "Generating C++ asset library cme::${CME_NAME}"
            ${CME_CODEGEN_ARG})
        add_library(cme_${CME_NAME} ${CME_TYPE} ${CME_SOURCE_FILE})
    elseif (CME_CXX_MODULE)
        set(CME_CXX_MODULE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cppm")
        add_custom_command(
            OUTPUT  ${CME_CXX_MODULE_FILE}
            DEPENDS ${CME_FILES}
            COMMAND ${CMAKE_COMMAND} ${CME_PARAMS}
            COMMENT "Generating C++20-Module asset library cme::${CME_NAME}"
            ${CME_CODEGEN_ARG})
        # CXX_MODULE libraries may not be INTERFACE like C or CXX
        if (CME_INTERFACE OR CME_CONSTEXPR)
            add_library(cme_${CME_NAME} OBJECT)
        else()
            add_library(cme_${CME_NAME} ${CME_TYPE})
        endif()
        target_sources(cme_${CME_NAME} PUBLIC
            FILE_SET cxx_module_file
            TYPE CXX_MODULES
            BASE_DIRS ${CMAKE_CURRENT_BINARY_DIR}
            FILES ${CME_CXX_MODULE_FILE})
    endif()

    # scope needs to be INTERFACE when INTERFACE/CONSTEXPR is used
    if ((CME_INTERFACE OR CME_CONSTEXPR) AND NOT CME_CXX_MODULE)
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
    elseif (CME_CXX OR CME_CXX_MODULE)
        if (CME_CXX_MODULE)
            # enforce C++20 for modules
            target_compile_features(cme_${CME_NAME} ${CME_LIBRARY_SCOPE} cxx_std_20)
        else()
            # enforce C++14 for frozen
            target_compile_features(cme_${CME_NAME} ${CME_LIBRARY_SCOPE} cxx_std_14)
        endif()

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
    if     (CME_LANGUAGE STREQUAL C)
        set(CME_C_FILE     "${CME_SOURCES_DIR}/cme_${CME_NAME}.c")
        set(CME_H_FILE     "${CME_INCLUDE_DIR}/cme/${CME_NAME}.h")
        set(CME_ASSET_FILE "${CME_INCLUDE_DIR}/cme/detail/asset.h")

        # asset.h header that will be shared by all C asset libs
        if (NOT EXISTS ${CME_ASSET_FILE})
            string(APPEND CME_ASSET_FILE_STRING
                "#pragma once\n"
                "#include <stdint.h>\n"
                "\n"
                "struct Asset {\n"
                "    const uint8_t* _data;\n"
                "    const uint64_t _size;\n"
                "};\n")
            file(WRITE ${CME_ASSET_FILE} "${CME_ASSET_FILE_STRING}")
        endif()

        # cme_{name}.c
        string(APPEND CME_C_FILE_STRING "#include <cme/detail/asset.h>\n\n")
        # {name}.h
        string(APPEND CME_H_FILE_STRING "#pragma once\n")
        if (CME_TYPE STREQUAL "INTERFACE")
            string(APPEND CME_H_FILE_STRING "#include <${CME_C_FILE}>\n")
        else()
            string(APPEND CME_H_FILE_STRING "#include <cme/detail/asset.h>\n\n")
        endif()

        # append #embed entries to header/source files
        if (NOT DEFINED CME_FILES)
            file(GLOB_RECURSE CME_FILES "${CME_BASE_DIR}/*")
        else()
            separate_arguments(CME_FILES)
        endif()
        foreach (ASSET_PATH_FULL ${CME_FILES})
            # get shortened path relative to shader directory root
            cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
            # replace illegal characters for C var names
            string(MAKE_C_IDENTIFIER ${ASSET_PATH_RELATIVE} ASSET_NAME)

            # add definition to C source
            string(APPEND CME_C_FILE_STRING
                "const uint8_t  ${ASSET_NAME}[] = {\n"
                "    #embed \"${ASSET_PATH_FULL}\"\n"
                "};\n"
                "const uint64_t ${ASSET_NAME}_size = sizeof ${ASSET_NAME};\n")
            # add declaration to C header
            if (NOT CME_TYPE STREQUAL "INTERFACE")
                string(APPEND CME_H_FILE_STRING
                    "extern const uint8_t* ${ASSET_NAME};\n"
                    "extern const uint64_t ${ASSET_NAME}_size;\n")
            endif()
        endforeach()

        # write the files to disk
        file(WRITE ${CME_C_FILE} "${CME_C_FILE_STRING}")
        file(WRITE ${CME_H_FILE} "${CME_H_FILE_STRING}")
    elseif (CME_LANGUAGE STREQUAL CXX)
        set(CME_CPP_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cpp")
        set(CME_HPP_FILE "${CME_INCLUDE_DIR}/cme/${CME_NAME}.hpp")
        set(CME_ASSET_FILE "${CME_INCLUDE_DIR}/cme/detail/asset.hpp")

        # asset.hpp header that will be shared by all C++ asset libs
        if (NOT EXISTS ${CME_ASSET_FILE})
            string(APPEND CME_ASSET_FILE_STRING
                "#pragma once\n"
                "#include <cstdint>\n"
                "#include <utility>\n"
                "\n"
                "namespace cme {\n"
                "    struct Asset {\n"
                "        // get data as array of T instead of uint8\n"
                "        template<typename T>\n"
                "        auto get() -> std::pair<T*, uint64_t> const {\n"
                "            const T* data = reinterpret_cast<const T*>(_data);\n"
                "            const uint64_t size = _size / sizeof(T);\n"
                "            return { data, size };\n"
                "        }\n"
                "        const uint8_t* _data;\n"
                "        const uint64_t _size;\n"
                "    };\n"
                "}\n")
            file(WRITE ${CME_ASSET_FILE} "${CME_ASSET_FILE_STRING}")
        endif()

        # {name}.hpp
        string(APPEND CME_HPP_FILE_STRING
            "#pragma once\n"
            "#include <string_view>\n"
            "#include <cme/detail/asset.hpp>\n")
        if (CME_TYPE STREQUAL "INTERFACE")
            string(APPEND CME_HPP_FILE_STRING
                "#include <${CME_CPP_FILE}>\n")
        else()
            string(APPEND CME_HPP_FILE_STRING
                "\n"
                "namespace ${CME_NAME} {\n"
                "    // load an embedded asset\n"
                "    auto load(const std::string_view path) -> cme::Asset;\n"
                "    // load an embedded asset if it exists\n"
                "    auto try_load(const std::string_view path) noexcept -> std::pair<cme::Asset, bool>;\n"
                "    // check if the path points to an embedded asset\n"
                "    auto exists(const std::string_view path) noexcept -> bool;\n"
                "}\n")
        endif()
        file(WRITE ${CME_HPP_FILE} "${CME_HPP_FILE_STRING}")
        
        # cme_{name}.cpp
        string(APPEND CME_CPP_FILE_STRING
            "#include <frozen/unordered_map.h>\n"
            "#include <frozen/string.h>\n"
            "#include <cme/detail/asset.hpp>\n"
            "\n"
            "namespace ${CME_NAME} {\n"
            "    namespace detail {\n")

        # append #embed entries to cme_{name}.cpp
        if (NOT DEFINED CME_FILES)
            file(GLOB_RECURSE CME_FILES "${CME_BASE_DIR}/*")
        else()
            separate_arguments(CME_FILES)
        endif()
        foreach (ASSET_PATH_FULL ${CME_FILES})
            # get shortened path relative to shader directory root
            cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
            # replace illegal characters to suit C var name (replace with "_" for the most part)
            string(MAKE_C_IDENTIFIER ${ASSET_PATH_RELATIVE} ASSET_NAME)

            # add definition to C++ source
            string(APPEND CME_CPP_FILE_STRING
                "        static constexpr uint8_t  ${ASSET_NAME}[] = {\n"
                "            #embed \"${ASSET_PATH_FULL}\"\n"
                "        };\n"
                "        static constexpr uint64_t ${ASSET_NAME}_size = sizeof ${ASSET_NAME};\n")
        endforeach()

        # build lookup map in cme_{name}.cpp
        list(LENGTH CME_FILES CME_ASSET_FILES_COUNT)
        string(APPEND CME_CPP_FILE_STRING
            "\n"
            "        constexpr frozen::unordered_map<frozen::string, cme::Asset, ${CME_ASSET_FILES_COUNT}> asset_map = {\n")
        foreach (ASSET_PATH_FULL ${CME_FILES})
            # get shortened path relative to shader directory root
            cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
            # replace illegal characters for C var names
            string(MAKE_C_IDENTIFIER ${ASSET_PATH_RELATIVE} ASSET_NAME)

            # add lookup entry
            string(APPEND CME_CPP_FILE_STRING
                "            { \"${ASSET_PATH_RELATIVE}\", { ${ASSET_NAME}, ${ASSET_NAME}_size }},\n")
        endforeach()
        
        # finalize cme_{name}.cpp
        if (CME_TYPE STREQUAL "INTERFACE")
            set(CME_CONSTEXPR_KEYWORD "constexpr ")
        endif()
        string(APPEND CME_CPP_FILE_STRING
            "        };\n"
            "    }\n"
            "    \n"
            "    auto ${CME_CONSTEXPR_KEYWORD}load(const std::string_view path) -> cme::Asset {\n"
            "        return detail::asset_map.at(path);\n"
            "    }\n"
            "    auto ${CME_CONSTEXPR_KEYWORD}try_load(const std::string_view path) noexcept -> std::pair<cme::Asset, bool> {\n"
            "        auto it = detail::asset_map.find(path);\n"
            "        if (it == detail::asset_map.cend()) return {{}, false};\n"
            "        else return { it->second, true };\n"
            "    }\n"
            "    auto ${CME_CONSTEXPR_KEYWORD}exists(const std::string_view path) noexcept -> bool {\n"
            "        return detail::asset_map.contains(path);\n"
            "    }\n"
            "}\n")


        file(WRITE ${CME_CPP_FILE} "${CME_CPP_FILE_STRING}")
    elseif (CME_LANGUAGE STREQUAL CXX_MODULE)
        set(CME_CXX_MODULE_FILE "${CME_SOURCES_DIR}/cme_${CME_NAME}.cppm")
        set(CME_ASSET_FILE "${CME_INCLUDE_DIR}/cme/detail/asset.hpp")

        # asset.hpp header that will be shared by all C++ asset libs
        if (NOT EXISTS ${CME_ASSET_FILE})
            string(APPEND CME_ASSET_FILE_STRING
                "#pragma once\n"
                "#include <cstdint>\n"
                "#include <utility>\n"
                "\n"
                "namespace cme {\n"
                "    struct Asset {\n"
                "        // get data as array of T instead of uint8\n"
                "        template<typename T>\n"
                "        auto get() -> std::pair<T*, uint64_t> const {\n"
                "            const T* data = reinterpret_cast<const T*>(_data);\n"
                "            const uint64_t size = _size / sizeof(T);\n"
                "            return { data, size };\n"
                "        }\n"
                "        const uint8_t* _data;\n"
                "        const uint64_t _size;\n"
                "    };\n"
                "}\n")
            file(WRITE ${CME_ASSET_FILE} "${CME_ASSET_FILE_STRING}")
        endif()

        # cme_{name}.cppm
        string(APPEND CME_CXX_MODULE_FILE_STRING
            "module;\n"
            "#include <frozen/unordered_map.h>\n"
            "#include <frozen/string.h>\n"
            "#include <cme/detail/asset.hpp>\n"
            "export module cme.${CME_NAME};\n"
            "\n"
            "namespace ${CME_NAME}::detail {\n")

        # append #embed entries
        if (NOT DEFINED CME_FILES)
            file(GLOB_RECURSE CME_FILES "${CME_BASE_DIR}/*")
        else()
            separate_arguments(CME_FILES)
        endif()
        foreach (ASSET_PATH_FULL ${CME_FILES})
            # get shortened path relative to shader directory root
            cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
            # replace illegal characters to suit C var name (replace with "_" for the most part)
            string(MAKE_C_IDENTIFIER ${ASSET_PATH_RELATIVE} ASSET_NAME)

            # add definition to C++ source
            string(APPEND CME_CXX_MODULE_FILE_STRING
                "    static constexpr uint8_t  ${ASSET_NAME}[] = {\n"
                "        #embed \"${ASSET_PATH_FULL}\"\n"
                "    };\n"
                "    static constexpr uint64_t ${ASSET_NAME}_size = sizeof ${ASSET_NAME};\n")
        endforeach()

        # build lookup map
        list(LENGTH CME_FILES CME_ASSET_FILES_COUNT)
        string(APPEND CME_CXX_MODULE_FILE_STRING
            "\n"
            "    constexpr frozen::unordered_map<frozen::string, cme::Asset, ${CME_ASSET_FILES_COUNT}> asset_map = {\n")
        foreach (ASSET_PATH_FULL ${CME_FILES})
            # get shortened path relative to shader directory root
            cmake_path(RELATIVE_PATH ASSET_PATH_FULL BASE_DIRECTORY ${CME_BASE_DIR} OUTPUT_VARIABLE ASSET_PATH_RELATIVE)
            # replace illegal characters for C var names
            string(MAKE_C_IDENTIFIER ${ASSET_PATH_RELATIVE} ASSET_NAME)

            # add lookup entry
            string(APPEND CME_CXX_MODULE_FILE_STRING
                "            { \"${ASSET_PATH_RELATIVE}\", { ${ASSET_NAME}, ${ASSET_NAME}_size }},\n")
        endforeach()

        # finalize cme_{name}.cppm
        string(APPEND CME_CXX_MODULE_FILE_STRING
            "    };\n"
            "}\n"
            "\n"
            "export namespace ${CME_NAME} {\n"
            "    auto constexpr load(const std::string_view path) -> cme::Asset {\n"
            "        return detail::asset_map.at(path);\n"
            "    }\n"
            "    auto constexpr try_load(const std::string_view path) noexcept -> std::pair<cme::Asset, bool> {\n"
            "        auto it = detail::asset_map.find(path);\n"
            "        if (it == detail::asset_map.cend()) return {{}, false};\n"
            "        else return { it->second, true };\n"
            "    }\n"
            "    auto constexpr exists(const std::string_view path) noexcept -> bool {\n"
            "        return detail::asset_map.contains(path);\n"
            "    }\n"
            "}\n")
        file(WRITE ${CME_CXX_MODULE_FILE} "${CME_CXX_MODULE_FILE_STRING}")
    endif()
endblock()
