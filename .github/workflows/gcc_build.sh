#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -euo pipefail

declare -A args

while (($# > 0)); do
  case "$1" in
    --binutils-tarball|\
    --binutils-version|\
    --gcc-tarball|\
    --gcc-version|\
    --gmp-tarball|\
    --gmp-version|\
    --mpfr-tarball|\
    --mpfr-version|\
    --mpc-tarball|\
    --mpc-version|\
    --output)
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

for opt in \
  binutils-tarball \
  binutils-version \
  gcc-tarball \
  gcc-version \
  gmp-tarball \
  gmp-version \
  mpfr-tarball \
  mpfr-version \
  mpc-tarball \
  mpc-version \
  output; do
  if [[ ! -v "args[$opt]" ]]; then
    echo "error: missing --$opt" >&2
    exit 1
  fi
done

mkdir binutils

mkdir binutils/src
tar xJf "${args[binutils-tarball]}" -C binutils/src --strip-components=1

mkdir binutils/build
(
  cd binutils/build
  ../src/configure \
    --prefix=/usr/local \
    --enable-default-hash-style=gnu \
    --enable-deterministic-archives \
    --enable-new-dtags \
    --enable-plugins \
    --enable-relro \
    --disable-multilib \
    --disable-nls \
    --disable-werror
)

make -C binutils/build -j"$(nproc)"

make -C binutils/build install-strip

mkdir gcc

mkdir gcc/src
tar xJf "${args[gcc-tarball]}" -C gcc/src --strip-components=1

mkdir gcc/src/gmp
tar xJf "${args[gmp-tarball]}" -C gcc/src/gmp --strip-components=1

mkdir gcc/src/mpfr
tar xJf "${args[mpfr-tarball]}" -C gcc/src/mpfr --strip-components=1

mkdir gcc/src/mpc
tar xJf "${args[mpc-tarball]}" -C gcc/src/mpc --strip-components=1

mkdir gcc/build
(
  cd gcc/build
  ../src/configure \
    --prefix=/usr/local \
    --enable-languages=c,c++ \
    --enable-checking=release \
    --enable-default-pie \
    --disable-multilib \
    --disable-nls \
    --with-as=/usr/local/bin/as \
    --with-ld=/usr/local/bin/ld \
    --with-gcc-major-version-only \
    --with-linker-hash-style=gnu
)

make -C gcc/build -j"$(nproc)" bootstrap2

mkdir pkg

DESTDIR="$PWD/pkg" make -C gcc/build install-strip
DESTDIR="$PWD/pkg" make -C binutils/build install-strip

mkdir pkg/etc
mkdir pkg/etc/ld.so.conf.d

cat > pkg/etc/ld.so.conf.d/000-local-lib.conf <<EOF
/usr/local/lib64
/usr/local/lib
EOF

mkdir pkg/DEBIAN

cat > pkg/DEBIAN/control <<EOF
Package: gcc-local
Version: ${args[gcc-version]}+binutils${args[binutils-version]}+gmp${args[gmp-version]}+mpfr${args[mpfr-version]}+mpc${args[mpc-version]}-1
Architecture: $(dpkg --print-architecture)
Maintainer: nobody <nobody@localhost>
Depends: libc6-dev
Description: none
EOF

cat > pkg/DEBIAN/triggers <<EOF
activate-noawait ldconfig
EOF

dpkg-deb --root-owner-group --build pkg "${args[output]}"
