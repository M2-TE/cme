cmake_minimum_required(VERSION 3.25)
project(cme LANGUAGES C CXX)

option(CME_BUILD_TESTS_C   "Build the C CME tests" ${PROJECT_IS_TOP_LEVEL})
option(CME_BUILD_TESTS_CXX "Build the CXX CME tests" ${PROJECT_IS_TOP_LEVEL})
option(CME_BUILD_TESTS_CXX_MODULE "Build the CXX_MODULE CME tests" ${PROJECT_IS_TOP_LEVEL})
include("${CMAKE_CURRENT_SOURCE_DIR}/cme.cmake")

if (CME_BUILD_TESTS_C OR CME_BUILD_TESTS_CXX)
    enable_testing()
endif()
if (CME_BUILD_TESTS_C)
    add_test(NAME cme.c.${CONFIGURATION}
        COMMAND ${CMAKE_CTEST_COMMAND}
            --build-and-test "${CMAKE_CURRENT_SOURCE_DIR}/tests" "${CMAKE_CURRENT_BINARY_DIR}/tests/c"
            --build-generator ${CMAKE_GENERATOR}
            --build-config ${CMAKE_BUILD_TYPE}
            --build-options -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER} -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER} -DCME_BUILD_TESTS_C=ON)
endif()
if (CME_BUILD_TESTS_CXX)
    add_test(NAME cme.cxx.${CONFIGURATION}
        COMMAND ${CMAKE_CTEST_COMMAND}
            --build-and-test "${CMAKE_CURRENT_SOURCE_DIR}/tests" "${CMAKE_CURRENT_BINARY_DIR}/tests/cxx"
            --build-generator ${CMAKE_GENERATOR}
            --build-config ${CMAKE_BUILD_TYPE}
            --build-options -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER} -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER} -DCME_BUILD_TESTS_CXX=ON)
endif()
if (CME_BUILD_TESTS_CXX_MODULE)
    add_test(NAME cme.cxx_module.${CONFIGURATION}
        COMMAND ${CMAKE_CTEST_COMMAND}
            --build-and-test "${CMAKE_CURRENT_SOURCE_DIR}/tests" "${CMAKE_CURRENT_BINARY_DIR}/tests/cxx_module"
            --build-generator ${CMAKE_GENERATOR}
            --build-config ${CMAKE_BUILD_TYPE}
            --build-options -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER} -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER} -DCME_BUILD_TESTS_CXX_MODULE=ON)
endif()