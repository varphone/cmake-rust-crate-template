# cmake-rust-crate-template

This template allows you to create a Rust crate that can be built with CMake.
It is useful for integrating a Rust library into a C++ project.

## Pre-requisites

- [CMake](https://cmake.org/download/) (>= 3.21)
- [Rust](https://www.rust-lang.org/tools/install) (>= 1.55)
- [vcpkg](https://vcpkg.io) (>= 2021.05.31)
- [cbindgen](https://crates.io/crates/cbindgen) (>= 0.19.0)

## Usage

1. Clone this repository
2. Replace all instances of `cmake-rust-crate-template` with your crate name

## Building

### Linux

```sh
cmake --preset vcpkg-x64-linux-release
cmake --build --preset vcpkg-x64-linux-release
```

### Windows

```pwsh
cmake --preset vcpkg-x64-windows-release
cmake --build --preset vcpkg-x64-windows-release
```

## FAQ

### How it works

The `rust_crate` function in `cmake/RustCrate.cmake` is used to build a Rust crate that matches a CMake target and generate bindings for `C` or `C++` projects.

1. Create a dummy CMake target with the same name as the Rust crate.
2. Build the Rust crate using the Rust toolchain.
3. Replace the dummy CMake target with the actual Rust crate target.
4. The Rust crate is now ready to be used as a normal target in CMake.

### Binding generation

We use [cbindgen](https://crates.io/crates/cbindgen) to generate the bindings, you can configure it in `CMakeLists.txt`:

```cmake
rust_crate(
    CBINDGEN "C++"
    CBINDGEN_C_EXT ".h"
    CBINDGEN_CXX_EXT ".hpp"
)
```

- `CBINDGEN`: The language to generate bindings for, can be `C`, `C++`, or `C_C++`, default is `C++`.
  - `C`: Generate C bindings only, the output file extension is `.h`.
  - `C++`: Generate C++ bindings only, the output file extension is `.h`.
  - `C_C++`: Generate both C and C++ bindings, the output file extensions are `.h` and `.hpp`.
- `CBINDGEN_C_EXT`: The output file extension for C bindings, default is `.h`.
- `CBINDGEN_CXX_EXT`: The output file extension for C++ bindings, default is `.hpp`.
