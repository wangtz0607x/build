#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

declare -A args

while (($# > 0)); do
  case "$1" in
    --llvm-tarball|--llvm-version|--output)
      if (($# < 2)); then
        echo "error: missing value for $1" >&2
        exit 1
      fi
      args["${1#--}"]="$2"
      shift 2
      ;;
    *)
      echo "error: unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

for opt in llvm-tarball llvm-version output; do
  if [[ ! -v "args[$opt]" ]]; then
    echo "error: missing --$opt" >&2
    exit 1
  fi
done

mkdir src
tar xJf "${args[llvm-tarball]}" -C src --strip-components=1

mkdir build
cmake \
  -S src/llvm \
  -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;libunwind" \
  -DLLVM_TARGETS_TO_BUILD=Native \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_TELEMETRY=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_LIBPFM=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DLLVM_ENABLE_Z3_SOLVER=OFF \
  -DLLVM_ENABLE_PLUGINS=OFF \
  -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF \
  -DRUNTIMES_CMAKE_ARGS="$(
    printf '%s' \
      '-DCOMPILER_RT_BUILD_SANITIZERS=OFF;' \
      '-DCOMPILER_RT_BUILD_XRAY=OFF;' \
      '-DCOMPILER_RT_BUILD_LIBFUZZER=OFF;' \
      '-DCOMPILER_RT_BUILD_PROFILE=OFF;' \
      '-DCOMPILER_RT_BUILD_CTX_PROFILE=OFF;' \
      '-DCOMPILER_RT_BUILD_MEMPROF=OFF;' \
      '-DCOMPILER_RT_BUILD_ORC=OFF;' \
      '-DCOMPILER_RT_BUILD_GWP_ASAN=OFF;' \
      '-DLIBCXX_ENABLE_STATIC=OFF;' \
      '-DLIBCXXABI_ENABLE_STATIC=OFF;' \
      '-DLIBUNWIND_ENABLE_STATIC=OFF'
  )" \
  -G Ninja

cmake --build build --target clang lld runtimes

for component in clang clang-resource-headers lld builtins runtimes; do
  cmake --install build --component "$component" --strip
done

ldconfig

rm -rf build

mkdir build
cmake \
  -S src/llvm \
  -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/usr/local/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/local/bin/clang++ \
  -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
  -DCMAKE_EXE_LINKER_FLAGS="-L/usr/local/lib -rtlib=compiler-rt -unwindlib=libunwind -fuse-ld=lld --ld-path=/usr/local/bin/ld.lld" \
  -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/local/lib -rtlib=compiler-rt -unwindlib=libunwind -fuse-ld=lld --ld-path=/usr/local/bin/ld.lld" \
  -DCMAKE_MODULE_LINKER_FLAGS="-L/usr/local/lib -rtlib=compiler-rt -unwindlib=libunwind -fuse-ld=lld --ld-path=/usr/local/bin/ld.lld" \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_ENABLE_PROJECTS="bolt;clang;clang-tools-extra;lld" \
  -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;libunwind" \
  -DLLVM_TARGETS_TO_BUILD=Native \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_TELEMETRY=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_LIBPFM=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DLLVM_ENABLE_Z3_SOLVER=OFF \
  -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
  -DCLANG_DEFAULT_RTLIB=compiler-rt \
  -DCLANG_DEFAULT_UNWINDLIB=libunwind \
  -DCLANG_DEFAULT_LINKER=lld \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF \
  -DRUNTIMES_CMAKE_ARGS="$(
    printf '%s' \
      '-DCMAKE_EXE_LINKER_FLAGS=-L/usr/local/lib;' \
      '-DCMAKE_SHARED_LINKER_FLAGS=-L/usr/local/lib;' \
      '-DCMAKE_MODULE_LINKER_FLAGS=-L/usr/local/lib;' \
      '-DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON;' \
      '-DCOMPILER_RT_USE_LLVM_UNWINDER=ON;' \
      '-DCOMPILER_RT_CXX_LIBRARY=libcxx;' \
      '-DSANITIZER_CXX_ABI=libc++;' \
      '-DSANITIZER_CXX_ABI_INTREE=ON;' \
      '-DLIBCXX_USE_COMPILER_RT=ON;' \
      '-DLIBCXX_HAS_ATOMIC_LIB=OFF;' \
      '-DLIBCXXABI_USE_COMPILER_RT=ON;' \
      '-DLIBCXXABI_USE_LLVM_UNWINDER=ON;' \
      '-DLIBUNWIND_USE_COMPILER_RT=ON'
  )" \
  -G Ninja

cmake --build build

mkdir pkg

DESTDIR="$PWD/pkg" cmake --install build --strip

cat > pkg/usr/local/bin/clang.cfg <<EOF
-L/usr/local/lib
EOF
cat > pkg/usr/local/bin/clang++.cfg <<EOF
-L/usr/local/lib
EOF

mkdir pkg/DEBIAN

cat > pkg/DEBIAN/control <<EOF
Package: llvm-local
Version: ${args[llvm-version]}-1
Architecture: $(dpkg --print-architecture)
Maintainer: nobody <nobody@localhost>
Depends: libc6-dev
Description: none
EOF

cat > pkg/DEBIAN/triggers <<EOF
activate-noawait ldconfig
EOF

dpkg-deb --root-owner-group --build pkg "${args[output]}"
