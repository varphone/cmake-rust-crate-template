cmake_minimum_required(VERSION 3.21)

project(cmake-rust-crate-template)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake")

include(RustCrate)

rust_crate(
    CBINDGEN "C++"
    # CBINDGEN_C_EXT ".h"
    # CBINDGEN_CXX_EXT ".hpp"
)
