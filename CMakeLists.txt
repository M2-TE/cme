cmake_minimum_required(VERSION 3.25)
project(cme LANGUAGES C CXX)

option(CME_BUILD_TESTS_C   "Build the C CME tests" ON) # TODO: set to OFF
option(CME_BUILD_TESTS_CXX "Build the CXX CME tests" ON) # TODO: set to OFF
include("${CMAKE_CURRENT_SOURCE_DIR}/cme.cmake")

# some WIP tests
if (CME_BUILD_TESTS_C)
    cme_create_library(c_assets STATIC C BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/assets")
    add_executable(test_c "tests/test.c")
    target_link_libraries(test_c PRIVATE cme::c_assets)
endif()
if (CME_BUILD_TESTS_CXX)
    cme_create_library(cxx_assets STATIC CXX BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/assets")
    add_executable(test_cpp "tests/test.cpp")
    target_link_libraries(test_cpp PRIVATE cme::cxx_assets)
endif()
if (CME_BUILD_TESTS_C AND CME_BUILD_TESTS_CXX)
    cme_create_library(both_assets STATIC C CXX BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/assets")
    add_executable(test_both_c   "tests/test_both.c")
    add_executable(test_both_cpp "tests/test_both.cpp")
    target_link_libraries(test_both_c   PRIVATE cme::both_assets)
    target_link_libraries(test_both_cpp PRIVATE cme::both_assets)
endif()