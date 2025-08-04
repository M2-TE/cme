cmake_minimum_required(VERSION 3.25)
project(cme LANGUAGES C CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cme.cmake")
set(BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../assets")

if (CME_BUILD_TESTS_C)
    # implicitly add all files within BASE_DIR
    cme_create_library(c_assets_implicit STATIC C BASE_DIR "${BASE_DIR}")
    add_executable(test_c_implicit "test_implicit.c")
    target_link_libraries(test_c_implicit PRIVATE cme::c_assets_implicit)

    # explicitly add ASSET_FILES with path relative to BASE_DIR
    file(GLOB_RECURSE ASSET_FILES CONFIGURE_DEPENDS "${BASE_DIR}/*")
    cme_create_library(c_assets_explicit STATIC C BASE_DIR "${BASE_DIR}" FILES ${ASSET_FILES})
    add_executable(test_c_explicit "test_explicit.c")
    target_link_libraries(test_c_explicit PRIVATE cme::c_assets_explicit)

    # implicitly add as INTERFACE
    cme_create_library(c_constexpr INTERFACE C BASE_DIR "${BASE_DIR}")
    add_executable(test_constexpr_c "test_constexpr.c")
    target_link_libraries(test_constexpr_c PRIVATE cme::c_constexpr)
elseif (CME_BUILD_TESTS_CXX)
    # implicitly add all files within BASE_DIR
    cme_create_library(cxx_assets_implicit STATIC CXX BASE_DIR "${BASE_DIR}")
    add_executable(test_cpp_implicit "test_implicit.cpp")
    target_link_libraries(test_cpp_implicit PRIVATE cme::cxx_assets_implicit)

    # explicitly add ASSET_FILES with path relative to BASE_DIR
    file(GLOB_RECURSE ASSET_FILES CONFIGURE_DEPENDS "${BASE_DIR}/*")
    cme_create_library(cxx_assets_explicit STATIC CXX BASE_DIR "${BASE_DIR}" FILES ${ASSET_FILES})
    add_executable(test_cpp_explicit "test_explicit.cpp")
    target_link_libraries(test_cpp_explicit PRIVATE cme::cxx_assets_explicit)

    # implicitly add as CONSTEXPR
    cme_create_library(cxx_constexpr CONSTEXPR CXX BASE_DIR "${BASE_DIR}")
    add_executable(test_constexpr_cpp "test_constexpr.cpp")
    target_link_libraries(test_constexpr_cpp PRIVATE cme::cxx_constexpr)
elseif (CME_BUILD_TESTS_CXX_MODULE)
    # test the C++20-Module as a STATIC library
    cme_create_library(cxx_module_assets STATIC CXX_MODULE BASE_DIR "${BASE_DIR}")
    add_executable(test_cpp_module "test_module.cpp")
    target_link_libraries(test_cpp_module PRIVATE cme::cxx_module_assets)
    target_compile_features(test_cpp_module PRIVATE cxx_std_20)
    set_target_properties(test_cpp_module PROPERTIES CXX_SCAN_FOR_MODULES ON)

    # test the C++20-Module as an INTERFACE library
    cme_create_library(cxx_module_assets_constexpr INTERFACE CXX_MODULE BASE_DIR "${BASE_DIR}")
    add_executable(test_cpp_module_constexpr "test_module_constexpr.cpp")
    target_link_libraries(test_cpp_module_constexpr PRIVATE cme::cxx_module_assets_constexpr)
    target_compile_features(test_cpp_module_constexpr PRIVATE cxx_std_20)
    set_target_properties(test_cpp_module_constexpr PROPERTIES CXX_SCAN_FOR_MODULES ON)
endif()