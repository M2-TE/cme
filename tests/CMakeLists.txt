cmake_minimum_required(VERSION 3.25)
project(cme LANGUAGES C CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cme.cmake")

if (CME_BUILD_TESTS_C)
    cme_create_library(c_assets STATIC C BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../assets")
    add_executable(test_c "test.c")
    target_link_libraries(test_c PRIVATE cme::c_assets)

    cme_create_library(c_constexpr CONSTEXPR C BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../assets")
    add_executable(test_constexpr_c "test_constexpr.c")
    target_link_libraries(test_constexpr_c PRIVATE cme::c_constexpr)
elseif (CME_BUILD_TESTS_CXX)
    cme_create_library(cxx_assets STATIC CXX BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../assets")
    add_executable(test_cpp "test.cpp")
    target_link_libraries(test_cpp PRIVATE cme::cxx_assets)

    cme_create_library(cxx_constexpr CONSTEXPR CXX BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../assets")
    add_executable(test_constexpr_cpp "test_constexpr.cpp")
    target_link_libraries(test_constexpr_cpp PRIVATE cme::cxx_constexpr)
endif()