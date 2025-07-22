cmake_minimum_required(VERSION 3.25)
project(cme LANGUAGES C CXX)

option(CME_BUILD_TESTS "Build the CME tests" ON)

include("${CMAKE_CURRENT_SOURCE_DIR}/cme.cmake")

# some WIP tests for dev purposes (for now at least)
if (CME_BUILD_TESTS)
    # if (CME_BUILD_C)
    #     add_executable(test_c   "tests/test.c")
    #     target_link_libraries(test_c   PRIVATE cme::c)
    # endif()

    # CXX test
    cme_create_library(assets STATIC CXX BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/assets")
    add_executable(test_cpp "tests/test.cpp")
    target_link_libraries(test_cpp PRIVATE cme::assets)
endif()