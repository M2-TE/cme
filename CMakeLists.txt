cmake_minimum_required(VERSION 3.25)
project(cme LANGUAGES C CXX)

option(CME_BUILD_TESTS_C   "Build the C CME tests" ${PROJECT_IS_TOP_LEVEL})
option(CME_BUILD_TESTS_CXX "Build the CXX CME tests" ${PROJECT_IS_TOP_LEVEL})
include("${CMAKE_CURRENT_SOURCE_DIR}/cme.cmake")

if (CME_BUILD_TESTS_C OR CME_BUILD_TESTS_CXX)
    enable_testing()
endif()

if (CME_BUILD_TESTS_C)
    add_test(NAME cme.c
        COMMAND ${CMAKE_CTEST_COMMAND}
            --build-and-test "${CMAKE_CURRENT_SOURCE_DIR}/tests"
                             "${CMAKE_CURRENT_BINARY_DIR}/tests/c"
            --build-generator ${CMAKE_GENERATOR}
            --build-options -DCME_BUILD_TESTS_C=ON -DCME_BUILD_TESTS_CXX=OFF)
endif()
if (CME_BUILD_TESTS_CXX)
    add_test(NAME cme.cxx
        COMMAND ${CMAKE_CTEST_COMMAND}
            --build-and-test "${CMAKE_CURRENT_SOURCE_DIR}/tests"
                             "${CMAKE_CURRENT_BINARY_DIR}/tests/cxx"
            --build-generator ${CMAKE_GENERATOR}
            --build-options -DCME_BUILD_TESTS_C=OFF -DCME_BUILD_TESTS_CXX=ON)
endif()
if (CME_BUILD_TESTS_C AND CME_BUILD_TESTS_CXX)
    add_test(NAME cme.c_cxx
        COMMAND ${CMAKE_CTEST_COMMAND}
            --build-and-test "${CMAKE_CURRENT_SOURCE_DIR}/tests"
                             "${CMAKE_CURRENT_BINARY_DIR}/tests/c_cxx"
            --build-generator ${CMAKE_GENERATOR}
            --build-options -DCME_BUILD_TESTS_C=ON -DCME_BUILD_TESTS_CXX=ON)
endif()