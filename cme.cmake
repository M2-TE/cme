cmake_minimum_required(VERSION 3.25)

function(cme_create_asset_library name)
    set(args_option STATIC SHARED C CXX)
    set(args_single BASE_DIR NAMESPACE)
    cmake_parse_arguments(CME "${args_option}" "${args_single}" "" "${ARGN}")

    # CME_* arg error handling
    if (DEFINED CME_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "CME: Unknown arguments (${CME_UNPARSED_ARGUMENTS})")
    endif()

    # Library type
    if (CME_STATIC AND CME_SHARED)
        message(FATAL_ERROR "CME: Asset library cannot be both STATIC and SHARED")
    elseif (CME_STATIC)
        set(CME_TYPE STATIC)
    elseif (DEFINED CME_SHARED)
        set(CME_TYPE SHARED)
    endif()

    # Enabled languages
    if (NOT CME_C AND NOT CME_CXX)
        set(CME_CXX TRUE)
    endif()

    # Asset library name
    set(CME_VALID_CHARS "^[a-zA-Z_][a-zA-Z0-9_]*[^!-\/:-@[-`{-~]$")
    if (NOT ${name} MATCHES ${CME_VALID_CHARS})
        message(FATAL_ERROR "CME: Library name (${name}) contains invalid characters")
    endif()
    set(CME_NAME ${name})

    # Base asset directory
    if (NOT DEFINED CME_BASE_DIR)
        message(FATAL_ERROR "CME: Requires BASE_DIR")
    elseif(NOT EXISTS ${CME_BASE_DIR})
        message(FATAL_ERROR "CME: Invalid BASE_DIR (${CME_BASE_DIR})")
    endif()

    # add_custom_command(
    #     OUTPUT  ${CME_CPP}
    #     DEPENDS ${CME_ASSET_FILES} ${CME_HPP}
    #     COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CME_CPP_INTERMEDIATE} ${CME_CPP}
    #     COMMENT "CME: Generating asset library \"${name}\"")

endfunction()
