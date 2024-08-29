# - CMake module to integrate Rust crates with CMake projects
# -
# - This module provides a set of functions to automatically add Rust libraries
# - to the CMake build system. It uses the `cargo` command to build the Rust
# - libraries and then copies the generated files to the CMake build directory.
# -
# - The module also provides a function to automatically set the project
# - information from the metadata in the `Cargo.toml` file.
# -
# - The module requires the `cbindgen` tool to generate the C and C++ headers
# - from the Rust code. The `cbindgen` tool can be installed using the following
# - command:
# -
# - ```sh
# - cargo install --force cbindgen
# - ```
# -
# - The module also requires the `cmake` tool to generate the CMake configuration
# - files. The `cmake` tool is usually installed with the CMake package.
# -
# - The module provides the following functions:
# -
# - - `rust_crate()`: Automatically sets the project information from the
# -   metadata in the `Cargo.toml` file.
# - - `rust_crate_setup_envs()`: Automatically sets the target triplet and linker for
# -   the build.
# -
# - Usage:
# -
# - ```cmake
# - cmake_minimum_required(VERSION 3.21)
# -
# - project(fake)
# -
# - set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
# -
# - rust_crate(
# -     CBINDGEN "C_C++"
# -     CBINDGEN_C_EXT ".h"
# -     CBINDGEN_CXX_EXT ".hpp"
# - )

# - Guard to prevent multiple inclusion
if(_rust_crate_included)
  return()
endif()
set(_rust_crate_included TRUE)

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

# - Automatically adds a Rust library to the build system
function(rust_crate_library TARGET)
  set(options SHARED STATIC)
  set(one_value_keywords CBINDGEN CBINDGEN_C_EXT CBINDGEN_CXX_EXT)
  set(multi_value_keywords)
  cmake_parse_arguments(_CAL "${options}" "${one_value_keywords}" "${multi_value_keywords}" ${ARGN})

  if(NOT _CAL_CBINDGEN)
    set(_CAL_CBINDGEN "C++")
  endif()
  if(NOT _CAL_CBINDGEN_C_EXT)
    set(_CAL_CBINDGEN_C_EXT ".h")
  endif()
  if(NOT _CAL_CBINDGEN_CXX_EXT)
    set(_CAL_CBINDGEN_CXX_EXT ".hpp")
  endif()

  if(_CAL_CBINDGEN STREQUAL "C" OR _CAL_CBINDGEN STREQUAL "c")
    set(FAKE_LIB_FILE ${CMAKE_CURRENT_BINARY_DIR}/src/lib.c)
  else()
    set(FAKE_LIB_FILE ${CMAKE_CURRENT_BINARY_DIR}/src/lib.cpp)
  endif()

  # Create a fake file to trigger the build system
  file(WRITE ${FAKE_LIB_FILE}
    "// This is a fake file to trigger the build system\n"
    "#include <${PROJECT_NAME}/${TARGET}.h>\n"
    "void fake() {}\n"
  )

  if(BUILD_SHARED_LIBS AND NOT _CAL_STATIC)
    set(_CAL_SHARED ON)
  elseif(NOT BUILD_SHARED_LIBS AND NOT _CAL_SHARED)
    set(_CAL_STATIC ON)
  endif()

  if(_CAL_SHARED AND _CAL_STATIC)
    message(FATAL_ERROR "Cannot set both SHARED and STATIC")
  elseif(_CAL_SHARED)
    add_library(${TARGET} SHARED ${FAKE_LIB_FILE})
    set(CRATE_TYPE "cdylib")
  elseif(_CAL_STATIC)
    add_library(${TARGET} STATIC ${FAKE_LIB_FILE})
    set(CRATE_TYPE "staticlib")
  endif()

  add_library(${PROJECT_NAME}::${TARGET} ALIAS ${TARGET})

  target_include_directories(${TARGET}
    PUBLIC
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
      $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
  )

  # if(NOT MSVC OR MINGW)
    set_target_properties(${TARGET}
      PROPERTIES
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR}
    )
  # endif()

  if(MSVC OR MINGW)
    if (_CAL_SHARED)
      set(TARGET_FILE_NAME ${TARGET}.dll)
    else()
      set(TARGET_FILE_NAME ${TARGET}.lib)
    endif()
  else()
    if(_CAL_SHARED)
      set(TARGET_FILE_NAME lib${TARGET}.so)
    else()
      set(TARGET_FILE_NAME lib${TARGET}.a)
    endif()
  endif()

  if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set(PROFILE_OPT "--release")
    set(PROFILE_NAME "release")
  else()
    set(PROFILE_OPT "")
    set(PROFILE_NAME "debug")
  endif()

  add_custom_command(TARGET ${TARGET} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      ${CMAKE_CURRENT_BINARY_DIR}/target/$ENV{CARGO_BUILD_TARGET}/${PROFILE_NAME}/${TARGET_FILE_NAME}
      $<TARGET_FILE:${TARGET}>
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  )

  if(MSVC AND _CAL_SHARED)
    add_custom_command(TARGET ${TARGET} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_CURRENT_BINARY_DIR}/target/$ENV{CARGO_BUILD_TARGET}/${PROFILE_NAME}/${TARGET_FILE_NAME}.lib
        $<TARGET_FILE_DIR:${TARGET}>/${TARGET}.lib
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_CURRENT_BINARY_DIR}/target/$ENV{CARGO_BUILD_TARGET}/${PROFILE_NAME}/${TARGET}.pdb
        $<TARGET_FILE_DIR:${TARGET}>/${TARGET}.pdb
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
  endif()

  if(_CAL_CBINDGEN STREQUAL "C" OR _CAL_CBINDGEN STREQUAL "c" OR _CAL_CBINDGEN STREQUAL "C++" OR _CAL_CBINDGEN STREQUAL "c++")
    add_custom_target(${TARGET}-cbindgen
      COMMAND ${CMAKE_COMMAND} -E env cbindgen --lang ${_CAL_CBINDGEN} --output ${CMAKE_CURRENT_SOURCE_DIR}/include/${PROJECT_NAME}/${TARGET}${_CAL_CBINDGEN_C_EXT}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
  elseif(_CAL_CBINDGEN STREQUAL "C_C++" OR _CAL_CBINDGEN STREQUAL "c_c++")
    add_custom_target(${TARGET}-cbindgen
      COMMAND ${CMAKE_COMMAND} -E env cbindgen --lang C --output ${CMAKE_CURRENT_SOURCE_DIR}/include/${PROJECT_NAME}/${TARGET}${_CAL_CBINDGEN_C_EXT}
      COMMAND ${CMAKE_COMMAND} -E env cbindgen --lang C++ --output ${CMAKE_CURRENT_SOURCE_DIR}/include/${PROJECT_NAME}/${TARGET}${_CAL_CBINDGEN_CXX_EXT}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
  endif()

  add_custom_target(${TARGET}-rust
    COMMAND ${CMAKE_COMMAND} -E env
      CARGO_BUILD_TARGET=$ENV{CARGO_BUILD_TARGET}
      CARGO_TARGET_$ENV{CARGO_BUILD_TARGET_UPPER}_LINKER=$ENV{CARGO_TARGET_$ENV{CARGO_BUILD_TARGET_UPPER}_LINKER}
      cargo rustc --crate-type ${CRATE_TYPE} ${PROFILE_OPT} --target-dir ${CMAKE_CURRENT_BINARY_DIR}/target
    COMMAND ${CMAKE_COMMAND} -E touch ${FAKE_LIB_FILE}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  )

  add_dependencies(${TARGET}
    ${TARGET}-cbindgen
    ${TARGET}-rust
  )

  set_target_properties(${TARGET}
    PROPERTIES
      ADDITIONAL_CLEAN_FILES "${CMAKE_CURRENT_BINARY_DIR}/target"
  )

  # Install targets
  install(TARGETS ${TARGET}
    EXPORT ${TARGET}Targets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Development
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Development
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR} COMPONENT Development
  )

  install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/${PROJECT_NAME}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR} COMPONENT Development
  )

  if(MSVC AND _CAL_SHARED)
    install(FILES
      $<TARGET_PDB_FILE:${TARGET}>
      DESTINATION ${CMAKE_INSTALL_BINDIR}
      COMPONENT Development
      OPTIONAL
    )
  endif()

  # Export targets
  install(EXPORT ${TARGET}Targets
    FILE ${TARGET}Targets.cmake
    NAMESPACE ${PROJECT_NAME}::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${TARGET}
  )

  # Export configuration files
  configure_package_config_file(
      ${CMAKE_SOURCE_DIR}/cmake/RustCrateConfig.cmake.in
      ${CMAKE_CURRENT_BINARY_DIR}/cmake/${TARGET}Config.cmake
      INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${TARGET}
  )

  write_basic_package_version_file(
      ${CMAKE_CURRENT_BINARY_DIR}/cmake/${TARGET}ConfigVersion.cmake
      VERSION ${PROJECT_VERSION}
      COMPATIBILITY AnyNewerVersion
  )

  export(PACKAGE ${TARGET})

  install(
    FILES
        ${CMAKE_CURRENT_BINARY_DIR}/cmake/${TARGET}Config.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/cmake/${TARGET}ConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME} COMPONENT Development
  )

  # Final export
  export(EXPORT ${TARGET}Targets
      FILE ${CMAKE_CURRENT_BINARY_DIR}/cmake/${TARGET}Targets.cmake
      NAMESPACE ${PROJECT_NAME}::
  )
endfunction(rust_crate_library)

# - Automatically sets the project information from the metadata
macro(rust_crate)
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env
      cargo metadata --no-deps --format-version 1 --manifest-path ${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml
    RESULT_VARIABLE _RESULT
    OUTPUT_VARIABLE _JSON_TEXT
    ERROR_QUIET
  )
  if (_RESULT)
    message(FATAL_ERROR "Failed to get the project metadata: ${_RESULT}")
  endif()

  # Read the package.name and package.version from the metadata
  string(JSON _PKG_NAME ERROR_VARIABLE _RESULT GET ${_JSON_TEXT} packages 0 name)
  if(_RESULT)
    message(FATAL_ERROR "Failed to get the package name: ${_RESULT}")
  endif()
  string(JSON _PKG_VERSION ERROR_VARIABLE _RESULT GET ${_JSON_TEXT} packages 0 version)
  if(_RESULT)
    message(FATAL_ERROR "Failed to get the package version: ${_RESULT}")
  endif()

  message(STATUS "Cargo: package.name = \"${_PKG_NAME}\"")
  message(STATUS "Cargo: package.version = \"${_PKG_VERSION}\"")

  string(REPLACE "-" "_" _LIB_NAME ${_PKG_NAME})

  project(${_LIB_NAME}
    VERSION ${_PKG_VERSION}
    LANGUAGES C CXX
  )

  rust_crate_library(${_LIB_NAME} ${ARGN})
endmacro(rust_crate)

# - Automatically sets the target triplet and linker for the build
macro(rust_crate_setup_envs)
  message(STATUS "Setting up the Cargo build environment")

  if (MSVC)
    if("${MSVC_C_ARCHITECTURE_ID}" STREQUAL "X86")
      set(_TRIPLET "i686-pc-windows-msvc")
    elseif("${MSVC_C_ARCHITECTURE_ID}" STREQUAL "x64")
      set(_TRIPLET "x86_64-pc-windows-msvc")
    elseif("${MSVC_C_ARCHITECTURE_ID}" STREQUAL "ARM")
      set(_TRIPLET "aarch64-pc-windows-msvc")
    else()
      message(FATAL_ERROR "Failed to determine the MSVC target triplet: ${MSVC_C_ARCHITECTURE_ID}")
    endif()
  else()
    if(NOT CMAKE_C_COMPILER AND NOT CMAKE_CXX_COMPILER)
      message(FATAL_ERROR "The C and C++ compilers are not set")
    elseif(NOT CMAKE_C_COMPILER)
      set(_COMPILER ${CMAKE_CXX_COMPILER})
    else()
      set(_COMPILER ${CMAKE_C_COMPILER})
    endif()
    execute_process(
      COMMAND ${_COMPILER} -dumpmachine
      RESULT_VARIABLE _RESULT
      OUTPUT_VARIABLE _MACHINE_TEXT
      ERROR_QUIET
    )
    if (_RESULT)
      message(FATAL_ERROR "Failed to determine target triplet: ${_RESULT}")
    endif()
    string(STRIP ${_MACHINE_TEXT} _MACHINE)
    if(_MACHINE STREQUAL "aarch64-linux-gnu")
      set(_TRIPLET "aarch64-unknown-linux-gnu")
    elseif(_MACHINE STREQUAL "arm-linux-gnueabi")
      set(_TRIPLET "arm-unknown-linux-gnueabi")
    elseif(_MACHINE STREQUAL "arm-linux-gnueabihf")
      set(_TRIPLET "arm-unknown-linux-gnueabihf")
    elseif(_MACHINE STREQUAL "i686-linux-gnu")
      set(_TRIPLET "i686-unknown-linux-gnu")
    elseif(_MACHINE STREQUAL "i686-w64-mingw32")
      set(_TRIPLET "i686-pc-windows-gnu")
      set(MINGW TRUE)
    elseif(_MACHINE STREQUAL "x86_64-linux-gnu")
      set(_TRIPLET "x86_64-unknown-linux-gnu")
    elseif(_MACHINE STREQUAL "x86_64-w64-mingw32")
      set(_TRIPLET "x86_64-pc-windows-gnu")
      set(MINGW TRUE)
    else()
      message(FATAL_ERROR "Unsupported target machine: ${_MACHINE}")
    endif()
  endif()

  if(MINGW)
    set(CMAKE_SHARED_LIBRARY_PREFIX "")
    set(CMAKE_STATIC_LIBRARY_PREFIX "")
    set(CMAKE_IMPORT_LIBRARY_PREFIX "")
  endif()

  # Set the target triplet
  set(ENV{CARGO_BUILD_TARGET} ${_TRIPLET})

  string(TOUPPER ${_TRIPLET} _TRIPLET_UPPER)
  string(REPLACE "-" "_" _TRIPLET_UPPER ${_TRIPLET_UPPER})
  set(ENV{CARGO_BUILD_TARGET_UPPER} ${_TRIPLET_UPPER})

  message(STATUS "Cargo: build.target = \"${_TRIPLET}\"")
  message(STATUS "Cargo: build.target.upper = \"${_TRIPLET_UPPER}\"")

  # Set the linker for the target
  if (NOT MSVC)
    if(NOT CARGO_TARGET_${_TRIPLET_UPPER}_LINKER)
      if (NOT CMAKE_C_COMPILER AND CMAKE_CXX_COMPILER)
        set(ENV{CARGO_TARGET_${_TRIPLET_UPPER}_LINKER} ${CMAKE_CXX_COMPILER})
      else()
        set(ENV{CARGO_TARGET_${_TRIPLET_UPPER}_LINKER} ${CMAKE_C_COMPILER})
      endif()
    endif()
    message(STATUS "Cargo: build.target.${_TRIPLET}.linker = \"$ENV{CARGO_TARGET_${_TRIPLET_UPPER}_LINKER}\"")
  endif()
endmacro()

# - Dump all variables
function(rust_crate_dump_vars)
  get_cmake_property(_variableNames VARIABLES)
  list (SORT _variableNames)
  foreach (_variableName ${_variableNames})
    if (ARGV0)
        unset(MATCHED)
        string(REGEX MATCH ${ARGV0} MATCHED ${_variableName})
        if (NOT MATCHED)
            continue()
        endif()
    endif()
    message(STATUS "${_variableName}=${${_variableName}}")
  endforeach()
endfunction()

rust_crate_setup_envs()
