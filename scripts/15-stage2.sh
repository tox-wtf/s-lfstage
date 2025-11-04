#!/bin/bash
set -euo pipefail # paranoia
# Build a stage 2 toolchain

# shellcheck disable=2086,2164,1091,2046

source "$ENVS/build.env"
cd     "$LFS/sources"


# M4
pre m4

sed 's/\[\[__nodiscard__]]//' -i lib/config.hin

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$LFS_BLD"  \
            --disable-nls       \
            --disable-rpath     \
            --disable-assert
make
make DESTDIR="$LFS" install


# Netbsd-curses
pre netbsd-curses

make CFLAGS="$CFLAGS" CC=gcc LDFLAGS="$LDFLAGS" PREFIX=/usr
make CFLAGS="$CFLAGS" CC=gcc LDFLAGS="$LDFLAGS" PREFIX=/usr DESTDIR=$LFS install

rm -vf "$LFS"/usr/lib/lib{panel,terminfo,menuw,curses,form,formw,panelw,menu,termcap,ncursesw,ncurses}.a


# Mksh
pre mksh

sh Build.sh -r
install -vDm755 mksh -t "$LFS/usr/bin/"
ln -sv mksh "$LFS/usr/bin/sh"


# Busybox
pre busybox

# Fix a bug in the menuconfig make target
sed -i 's,^main() ,int &,' scripts/kconfig/lxdialog/check-lxdialog.sh

cp -vf ../bb-conf .config
make

install -vDm755 busybox -t "$LFS/usr/bin/"


# File
# pre file
#
# _cfg=(
#     --disable-libseccomp
#     --disable-zlib
#     --disable-bzlib
#     --disable-xzlib
#     --disable-lzlib
#     --disable-zstdlib
#     --disable-lrziplib
#     --disable-shared
#     --disable-static
# )
#
# mkdir -v build
# cd build
#     ../configure "${_cfg[@]}"
#     make
# cd ..
#
# ./configure "${_cfg[@]}"    \
#     --prefix=/usr           \
#     --host="$LFS_TGT"       \
#     --build="$LFS_BLD"      \
#     --enable-shared         \
#     --datadir=/usr/share/file
#
# unset _cfg
#
# make FILE_COMPILE="$(pwd)/build/src/file"
# make DESTDIR="$LFS" install
# rm -vf "$LFS/usr/lib/libmagic.la"


# Pigz
# pre pigz
#
# # TODO:
# ./configure --prefix=/usr --host="$LFS_TGT"
# make
# make DESTDIR="$LFS" install


# Make
pre make

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$LFS_BLD"  \
            --disable-nls       \
            --disable-rpath
make
make DESTDIR="$LFS" install


# Binutils - Pass 2
pre binutils

patch << '.'
--- ltmain.sh
+++ ltmain.sh
@@ -6031 +6031 @@
-		    add_dir="$add_dir -L$inst_prefix_dir$libdir"
+		    add_dir="-L$inst_prefix_dir$libdir"
.

mkdir -v build
cd       build

../configure            \
    --prefix=/usr       \
    --build="$LFS_BLD"  \
    --host="$LFS_TGT"   \
    --disable-nls       \
    --enable-shared     \
    --disable-gprofng   \
    --disable-werror    \
    --enable-64-bit-bfd \
    --enable-new-dtags  \
    --enable-default-hash-style=gnu
make
make DESTDIR="$LFS" install

rm -v "$LFS"/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}


# GCC - Pass 2
# NOTE: This breaks the cross toolchain, but this doesn't matter since we chroot
# immediately after.
pre gcc

tar -xf ../mpfr-[0-9]*.tar.xz
mv -v mpfr-[0-9]* mpfr
tar -xf ../gmp-[0-9]*.tar.xz
mv -v gmp-[0-9]* gmp
tar -xf ../mpc-[0-9]*.tar.gz
mv -v mpc-[0-9]* mpc

sed -i '/m64=/s/lib64/lib/' gcc/config/i386/t-linux64

# TODO: Conclude whether this is necessary to patch the default interpreter
sed -i 's,/lib64/ld-linux,/usr/lib/ld-linux,g' gcc/config/i386/linux64.h

sed '/thread_header =/s/@.*@/gthr-posix.h/' \
    -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

mkdir -v build
cd       build

../configure                    \
    --build="$LFS_BLD"          \
    --host="$LFS_TGT"           \
    --target="$LFS_TGT"         \
    --prefix=/usr               \
    --with-build-sysroot="$LFS" \
    --enable-default-pie        \
    --enable-default-ssp        \
    --disable-nls               \
    --disable-multilib          \
    --disable-libatomic         \
    --disable-libgomp           \
    --disable-libquadmath       \
    --disable-libsanitizer      \
    --disable-libssp            \
    --disable-libvtv            \
    --enable-languages=c,c++    \
    LDFLAGS_FOR_TARGET="-L$PWD/$LFS_TGT/libgcc"
make
make DESTDIR="$LFS" install

# Install compatibility stuff
ln -sfv gcc "$LFS/usr/bin/cc"

# c99 wrapper
install -vDm755 /dev/stdin "$LFS/usr/bin/c99" << '.'
#!/bin/sh
exec gcc -std=c99 -pedantic "$@"
.

# c89 wrapper
install -vDm755 /dev/stdin "$LFS/usr/bin/c89" << '.'
#!/bin/sh
exec gcc -std=c89 -pedantic "$@"
.

post
msg "Finished building stage 2"
