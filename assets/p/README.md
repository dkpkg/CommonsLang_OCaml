# patches

## ocaml-5.4.1-configure.patch

1. Since LLVM-MinGW uses a clang compiler, the value of `ocaml_cc_vendor` is a value like `mingw-14-0-clang-21-1`. So expand `mingw-*-*-gcc-*` tests to include clang.
