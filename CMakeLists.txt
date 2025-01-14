# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

cmake_minimum_required(VERSION 3.10)
include(CheckCXXCompilerFlag)

project(
    proxygen
)
set(CMAKE_CXX_STANDARD_COMPUTED_DEFAULT 20)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_MODULE_PATH
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake"
  # for in-fbsource builds
  "${CMAKE_CURRENT_SOURCE_DIR}/../opensource/fbcode_builder/CMake"
  # For shipit-transformed builds
  "${CMAKE_CURRENT_SOURCE_DIR}/build/fbcode_builder/CMake"
  ${CMAKE_MODULE_PATH})
  
option(HTTP3_SUPPORT 
 "If enabled mvfst will be needed" 
 OFF)
 
option(BUILD_SHARED_LIBS
  "If enabled, build proxygen as a shared library.  \
  This is generally discouraged, since proxygen does not commit to having \
  a stable ABI."
  OFF
)
option(BUILD_SAMPLES
  "If enabled, proxygen will build various examples/samples"
  OFF
)
# Mark BUILD_SHARED_LIBS as an "advanced" option, since enabling it
# is generally discouraged.
mark_as_advanced(BUILD_SHARED_LIBS)

include(FBBuildOptions)
fb_activate_static_library_option()

# PROXYGEN_FBCODE_ROOT is where the top level proxygen/ directory resides, so
# an #include <proxygen/path/to/file> will resolve to
# $PROXYGEN_FBCODE_ROOT/proxygen/path/to/file on disk
set(PROXYGEN_FBCODE_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# Similarly, PROXYGEN_GENERATED_ROOT is where the top level proxygen/ directory
# resides for generated files, so a #include <proxygen/path/to/generated/file>
# will be at $PROXYGEN_GENERATED_ROOT/proxygen/path/to/generated/file
set(PROXYGEN_GENERATED_ROOT ${CMAKE_CURRENT_BINARY_DIR}/generated)
file(MAKE_DIRECTORY ${PROXYGEN_GENERATED_ROOT})

# Build-time program requirements.
if(WIN32)
    find_program(PROXYGEN_PYTHON python)
else()
    find_program(PROXYGEN_PYTHON python3)
endif()

if(NOT PROXYGEN_PYTHON)
    message(FATAL_ERROR "python is required for the proxygen build")
endif()

find_program(PROXYGEN_GPERF gperf)
if(NOT PROXYGEN_GPERF)
    message(FATAL_ERROR "gperf is required for the proxygen build")
endif()

# Dependencies
#
# IMPORTANT: If you change this, make the analogous update in:
#   cmake/proxygen-config.cmake.in
find_package(fmt CONFIG REQUIRED)
find_package(folly CONFIG REQUIRED)
find_package(wangle CONFIG REQUIRED)
if(HTTP3_SUPPORT)
find_package(mvfst CONFIG REQUIRED)
endif()
find_package(zstd CONFIG REQUIRED)
find_package(ZLIB REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(Threads)
find_package(Boost 1.58 REQUIRED
  COMPONENTS
    iostreams
    context
    filesystem
    program_options
    regex
    system
    thread
    chrono
)
# Set warning flags based on the compiler
if (MSVC)
	add_compile_options(/W1)
	# Disable specific warnings
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS /wd4100) # Unused parameter
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS /wd4127) # Conditional expression is constant
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS /wd4324) # Structure was padded due to alignment specifier
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS /wd4514) # Unreferenced inline function has been removed
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS /wd4625) # Copy constructor was implicitly defined as deleted
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS /wd4626) # Assignment operator was implicitly defined as deleted
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS /wd4710) # Function not inlined
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS /wd4711) # Function selected for automatic inline expansion
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS /wd4820) # Padding added after data member
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS /wd5026) # Move constructor was implicitly defined as deleted
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS /wd5027) # Move assignment operator was implicitly defined as deleted

else()
    list(APPEND
    _PROXYGEN_COMMON_COMPILE_OPTIONS
    -Wall
    -Wextra
	)
	CHECK_CXX_COMPILER_FLAG(-Wnoexcept-type COMPILER_HAS_W_NOEXCEPT_TYPE)
if (COMPILER_HAS_W_NOEXCEPT_TYPE)
  list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS -Wno-noexcept-type)
endif()
CHECK_CXX_COMPILER_FLAG(-Wunused-parameter COMPILER_HAS_W_UNUSED_PARAMETER)
if (COMPILER_HAS_W_UNUSED_PARAMETER)
  list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS -Wno-unused-parameter)
endif()
CHECK_CXX_COMPILER_FLAG(-Wmissing-field-initializers COMPILER_HAS_W_MISSING_FIELD_INITIALIZERS)
if (COMPILER_HAS_W_MISSING_FIELD_INITIALIZERS)
  list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS -Wno-missing-field-initializers)
endif()
CHECK_CXX_COMPILER_FLAG(-Wnullability-completeness COMPILER_HAS_W_NULLABILITY_COMPLETENESS)
if (COMPILER_HAS_W_NULLABILITY_COMPLETENESS)
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS -Wno-nullability-completeness)
endif()
CHECK_CXX_COMPILER_FLAG(-Wdeprecated-register COMPILER_HAS_W_DEPRECATED_REGISTER)
if (COMPILER_HAS_W_DEPRECATED_REGISTER)
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS -Wno-deprecated-register)
endif()
CHECK_CXX_COMPILER_FLAG(-Wregister COMPILER_HAS_W_REGISTER)
if (COMPILER_HAS_W_REGISTER)
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS -Wno-register)
endif()
CHECK_CXX_COMPILER_FLAG(-Wunused-value COMPILER_HAS_W_UNUSED_VALUE)
if (COMPILER_HAS_W_UNUSED_VALUE)
    list(APPEND _PROXYGEN_COMMON_COMPILE_OPTIONS -Wno-unused-value)
endif()
	endif()




SET(GFLAG_DEPENDENCIES "")
SET(PROXYGEN_EXTRA_LINK_LIBRARIES "")
SET(PROXYGEN_EXTRA_INCLUDE_DIRECTORIES "include")

find_package(gflags CONFIG REQUIRED)
list(APPEND CMAKE_REQUIRED_LIBRARIES gflags::gflags)

include(ProxygenTest)

add_subdirectory(proxygen)

if (NOT DEFINED LIB_INSTALL_DIR)
    set(LIB_INSTALL_DIR "lib")
endif()

if (NOT DEFINED CMAKE_INSTALL_DIR)
    set(CMAKE_INSTALL_DIR "${LIB_INSTALL_DIR}/cmake/proxygen/")
endif()

install(
    EXPORT proxygen-exports
    FILE proxygen-targets.cmake
    NAMESPACE proxygen::
    DESTINATION ${CMAKE_INSTALL_DIR}
)
include(CMakePackageConfigHelpers)
configure_package_config_file(
    cmake/proxygen-config.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/proxygen-config.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_DIR}
)
install(
    FILES ${CMAKE_CURRENT_BINARY_DIR}/proxygen-config.cmake
    DESTINATION ${CMAKE_INSTALL_DIR}
)

# uninstall target
if(NOT TARGET uninstall)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
        IMMEDIATE @ONLY)

    add_custom_target(uninstall
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
endif()
