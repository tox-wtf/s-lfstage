#!/bin/bash
set -euo pipefail # paranoia
# Build a stage 2 toolchain

# shellcheck disable=2086,2164,1091,2046

source "$ENVS/build.env"
cd     "$LFS/sources"


# M4
pre m4

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$LFS_BLD"  \
            --disable-nls       \
            --disable-rpath     \
            --disable-assert
make
make DESTDIR="$LFS" install


# Ncurses
pre ncurses

mkdir build
pushd build
    ../configure --prefix="$LFS/tools" AWK=gawk
    make -C include
    make -C progs tic
    install -vDm755 progs/tic -t "$LFS/tools/bin/"
popd

./configure --prefix=/usr                   \
            --host="$LFS_TGT"               \
            --build="$LFS_BLD"              \
            --mandir=/usr/share/man         \
            --with-manpage-format=normal    \
            --with-shared                   \
            --without-normal                \
            --with-cxx-shared               \
            --without-tests                 \
            --without-debug                 \
            --without-profile               \
            --without-ada                   \
            --disable-stripping             \
            --disable-nls                   \
            --disable-rpath                 \
            --disable-home-terminfo         \
            AWK=gawk

make
make DESTDIR="$LFS" install
ln -sv libncursesw.so "$LFS/usr/lib/libncurses.so"
sed -i 's/^#if.*XOPEN.*$/#if 1/' "$LFS/usr/include/curses.h"


# Bash
pre bash

./configure --prefix=/usr           \
            --host="$LFS_TGT"       \
            --build="$LFS_BLD"      \
            --disable-nls           \
            --disable-rpath         \
            --without-bash-malloc   \
            --disable-bang-history

make
make DESTDIR="$LFS" install
ln -sv bash "$LFS/usr/bin/sh"


# Coreutils
pre coreutils

./configure --prefix=/usr                     \
            --sbindir=/usr/bin                \
            --libexecdir=/usr/lib             \
            --host="$LFS_TGT"                 \
            --build="$LFS_BLD"                \
            --disable-assert                  \
            --disable-rpath                   \
            --disable-nls                     \
            --enable-install-program=hostname \
            --enable-no-install-program=arch,kill,uptime,base32,b2sum,basenc,chcon,cksum,csplit,dd,df,dir,dircolors,expand,factor,false,fmt,fold,groups,hostid,join,link,logname,md5sum,nice,nl,nohup,numfmt,paste,pathchk,pinky,pr,ptx,runcon,sha224sum,sha384sum,shred,stdbuf,stty,sync,timeout,true,truncate,tsort,tty,unexpand,unlink,users,vdir,who,whoami

make
make DESTDIR="$LFS" install


# Diffutils
pre diffutils

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$LFS_BLD"  \
            --disable-nls       \
            --disable-rpath     \
            gl_cv_func_strcasecmp_works=y

make
make DESTDIR="$LFS" install


# File
pre file

_cfg=(
    --disable-libseccomp
    --disable-zlib
    --disable-bzlib
    --disable-xzlib
    --disable-lzlib
    --disable-zstdlib
    --disable-lrziplib
    --disable-shared
    --disable-static
)

mkdir -v build
cd build
    ../configure "${_cfg[@]}"
    make
cd ..

./configure "${_cfg[@]}"    \
    --prefix=/usr           \
    --host="$LFS_TGT"       \
    --build="$LFS_BLD"      \
    --enable-shared         \
    --datadir=/usr/share/file

unset _cfg

make FILE_COMPILE="$(pwd)/build/src/file"
make DESTDIR="$LFS" install
rm -vf "$LFS/usr/lib/libmagic.la"


# Findutils
pre findutils

./configure --prefix=/usr                   \
            --libexecdir=/usr/lib           \
            --host="$LFS_TGT"               \
            --build="$LFS_BLD"              \
            --disable-assert                \
            --disable-nls                   \
            --disable-rpath                 \
            --localstatedir=/var/lib/locate

make
make DESTDIR="$LFS" install


# Gawk
pre gawk

sed -i 's/extras//' Makefile.in
./configure --prefix=/usr           \
            --libexecdir=/usr/lib   \
            --host="$LFS_TGT"       \
            --build="$LFS_BLD"      \
            --disable-nls           \
            --disable-rpath

make
make DESTDIR=$LFS install


# Grep
pre grep

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$LFS_BLD"  \
            --disable-nls       \
            --disable-rpath     \
            --disable-assert

make
make DESTDIR=$LFS install


# Gzip
pre gzip

./configure --prefix=/usr --host="$LFS_TGT"
make
make DESTDIR="$LFS" install


# Make
pre make

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$LFS_BLD"  \
            --disable-nls       \
            --disable-rpath

make
make DESTDIR="$LFS" install


# Patch
pre patch

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$LFS_BLD"

make
make DESTDIR="$LFS" install


# Sed
pre sed

./configure --prefix=/usr       \
            --host="$LFS_TGT"   \
            --build="$LFS_BLD"  \
            --disable-acl       \
            --disable-i18n      \
            --disable-assert    \
            --disable-nls       \
            --disable-rpath

make
make DESTDIR="$LFS" install


# Tar
pre tar

./configure --prefix=/usr           \
            --libexecdir=/usr/lib   \
            --host="$LFS_TGT"       \
            --build="$LFS_BLD"      \
            --disable-acl           \
            --disable-nls           \
            --disable-rpath

make
make DESTDIR="$LFS" install


# Xz
pre xz

./configure --prefix=/usr           \
            --host="$LFS_TGT"       \
            --build="$LFS_BLD"      \
            --disable-microlzma     \
            --disable-lzip-decoder  \
            --enable-small          \
            --enable-threads=posix  \
            --disable-lzmadec       \
            --disable-lzmainfo      \
            --disable-lzma-links    \
            --disable-scripts       \
            --disable-doc           \
            --disable-nls           \
            --disable-rpath         \
            --disable-static

make
make DESTDIR="$LFS" install
rm -v "$LFS/usr/lib/liblzma.la"


# Binutils - Pass 2
pre binutils

sed -i '6031s/$add_dir//' ltmain.sh

mkdir -v build
cd       build

../configure                        \
    --prefix=/usr                   \
    --build="$LFS_BLD"              \
    --host="$LFS_TGT"               \
    --disable-nls                   \
    --enable-shared                 \
    --disable-gprofng               \
    --disable-werror                \
    --enable-64-bit-bfd             \
    --enable-new-dtags              \
    --disable-gdb                   \
    --disable-gdbserver             \
    --disable-libdecnumber          \
    --disable-readline              \
    --disable-sim                   \
    --enable-default-hash-style=gnu

make
make DESTDIR="$LFS" install

rm -vf "$LFS"/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}


# GCC - Pass 2
# NOTE: This breaks the cross toolchain, but this doesn't matter since we chroot
# immediately after.
pre gcc

tar -xf ../mpfr-[0-9]*.tar.?z
mv -vf mpfr-[0-9]* mpfr
tar -xf ../gmp-[0-9]*.tar.?z
mv -vf gmp-[0-9]* gmp
tar -xf ../mpc-[0-9]*.tar.?z
mv -vf mpc-[0-9]* mpc
# tar -xf ../isl-[0-9]*.tar.?z
# mv -vf isl-[0-9]* isl

sed -i '/m64=/s/lib64/lib/' gcc/config/i386/t-linux64

# TODO: Conclude whether this is necessary to patch the default interpreter
sed -i 's,/lib64/ld-linux,/usr/lib/ld-linux,g' gcc/config/i386/linux64.h

sed -i '/thread_header =/s/@.*@/gthr-posix.h/' libgcc/Makefile.in libstdc++-v3/include/Makefile.in

mkdir -v build
cd       build

../configure                        \
    --build="$LFS_BLD"              \
    --host="$LFS_TGT"               \
    --target="$LFS_TGT"             \
    --prefix=/usr                   \
    --bindir=/usr/bin               \
    --sbindir=/usr/bin              \
    --libexecdir=/usr/lib           \
    --with-build-sysroot="$LFS"     \
    --enable-default-pie            \
    --enable-default-ssp            \
    --disable-nls                   \
    --disable-multilib              \
    --disable-fixincludes           \
    --disable-libatomic             \
    --disable-libgomp               \
    --disable-libquadmath           \
    --disable-libsanitizer          \
    --disable-libssp                \
    --disable-libvtv                \
    --enable-languages=c,c++        \
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
