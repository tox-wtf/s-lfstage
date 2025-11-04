#!/usr/bin/mksh
set -euo pipefail
# At this point, we're into stage 3 territory. This script is run as chroot.
#
# Packages:
# * Which           - Compilation convenience
# * Gettext-Tiny    - Minimal gettext implementation
# * Bison           - Dependency of Glibc
# * Iana-etc        - Nice to have
# * Zstd            - Needed by To
# * Zlib            - Dependency of Binutils
# * Flex            - Compilation convenience
# * Groff           - Compilation convenience
# * Pkgconf         - Compilation convenience


# Make utilities available
busybox --install /usr/bin


# shellcheck disable=2068,1091
. /build.env


# Create some necessary stuff
ln -sfv /run /var/run
ln -sfv /run/lock /var/lock
install -vdm 1777 /run /tmp /var/tmp
install -vdm 0555 /proc /sys
install -vdm 0755 /dev


# Set up basic networking
install -vDm644 /dev/stdin /etc/hosts << .
127.0.0.1  localhost s
::1        localhost s
.

install -vDm644 /dev/stdin /etc/hostname << .
s-container
.

install -vDm644 /dev/stdin /etc/resolv.conf << .
nameserver 9.9.9.9
nameserver 8.8.8.8
nameserver 1.1.1.1
.


# Set up users and groups
install -vDm644 /dev/stdin /etc/passwd << .
_:x:0:0:_:/home/_:/bin/mksh
s:x:1000:1000:s builder:/home/s:/bin/mksh
nobody:x:65534:65534:unprivileged user:/dev/null:/usr/bin/false
.

install -vDm644 /dev/stdin /etc/group << .
_:x:0:
wheel:x:97:
users:x:999:
s:x:1000:
nogroup:x:65534:
.


# Install home directories
install -o _ -vdm700 /home/_
install -o s -vdm700 /home/s


# Which
install -vDm755 /dev/stdin /usr/bin/which << '.'
#!/bin/sh
whence -v "$@" | grep -o '/.\+$'
exit ${PIPESTATUS[0]}
.


# Gettext-Tiny
pre gettext-tiny

make LIBINTL=NOOP
make LIBINTL=NOOP prefix=/usr install


# Byacc
pre bison

./configure --prefix=/usr
make
make install


# Iana-etc
pre iana-etc
cp -vf services protocols /etc


# Python
# pre Python
#
# ./configure --prefix=/usr           \
#             --enable-shared         \
#             --disable-test-modules  \
#             --without-dtrace        \
#             --without-valgrind      \
#             --without-ensurepip     \
#             --without-static-libpython
# make
# make install
#
# rm -vf /usr/bin/idle3*
# rm -rf /usr/lib/python3.[0-9]*/idlelib


# TODO: Consider not rebuilding Glibc, allowing us to skip Python entirely
# Glibc
# pre glibc
#
# mkdir -v build
# cd       build
#
# printf "sbindir=/usr/bin\nrootsbindir=/usr/bin\n" > configparms
# ../configure --prefix=/usr                   \
#              --disable-werror                \
#              --disable-nscd                  \
#              libc_cv_slibdir=/usr/lib        \
#              libc_cv_rtlddir=/usr/lib        \
#              --enable-stack-protector=strong \
#              --enable-kernel=6.12
# make
#
# touch /etc/ld.so.conf
# # shellcheck disable=2016
# sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
#
# make install
#
# # Remove unused interpreters from the ldd script
# patch -Np0 -d "$LFS/usr/bin/" << .
# --- ldd.orig
# +++ ldd
# @@ -29 +29 @@
# -RTLDLIST="/usr/lib64/ld-linux-x86-64.so.2 /usr/lib/ld-linux.so.2 /usr/libx32/ld-linux-x32.so.2"
# +RTLDLIST="/usr/lib/ld-linux-x86-64.so.2"
# .

mkdir -pv /usr/lib/locale
localedef -i C     -f UTF-8 C.UTF-8
localedef -i en_US -f UTF-8 en_US.UTF-8

install -vDm644 /dev/stdin /etc/nsswitch.conf << .
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
.


# Zstd
pre zstd

make prefix=/usr
make prefix=/usr install
rm -vf /usr/lib/libzstd.a


# Zlib
pre zlib-ng
./configure --prefix=/usr --shared --zlib-compat
make
make install


# Pigz
pre pigz
make pigz
install -vDm755 pigz /usr/bin/gzip
# TODO: Include ungzip, zcat, etc


# Flex
pre flex
./configure --prefix=/usr       \
            --disable-static    \
            --disable-nls       \
            --disable-rpath
make
make install
ln -sv flex /usr/bin/lex


# Groff
# pre groff
# PAGE=letter \
# ./configure --prefix=/usr       \
#             --disable-rpath     \
#             --without-x         \
#             --without-uchardet
# make
# make install


# Pkgconf
pre pkgconf
./configure --prefix=/usr --disable-static
make
make install
ln -sv pkgconf /usr/bin/pkg-config


# Binutils
# pre binutils
#
# mkdir -v build
# cd       build
#
# ../configure --prefix=/usr       \
#              --sysconfdir=/etc   \
#              --enable-ld=default \
#              --enable-plugins    \
#              --enable-shared     \
#              --disable-werror    \
#              --enable-64-bit-bfd \
#              --enable-new-dtags  \
#              --with-system-zlib  \
#              --enable-default-hash-style=gnu
# make tooldir=/usr
# make tooldir=/usr install

rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
        /usr/share/doc/gprofng/


# GMP
# pre gmp
#
# sed '/long long t1;/,+1s/()/(...)/' -i configure
# ./configure --prefix=/usr       \
#             --enable-cxx        \
#             --disable-static
# make
# make install


# MPFR
# pre mpfr
#
# ./configure --prefix=/usr       \
#             --disable-static    \
#             --enable-thread-safe
# make
# make check # all 198 tests should pass
# make install


# MPC
# pre mpc
# ./configure --prefix=/usr --disable-static
# make
# make install


# ISL
# pre isl
# ./configure --prefix=/usr --disable-static
# make
# make install
#
# mkdir -pv /usr/share/gdb/auto-load/usr/lib
# mv -v /usr/lib/libisl*gdb.py /usr/share/gdb/auto-load/usr/lib


# GCC
# pre gcc
#
# sed -e '/m64=/s/lib64/lib/' \
#     -i.orig gcc/config/i386/t-linux64
#
# mkdir -v build
# cd       build
#
# ../configure --prefix=/usr            \
#              LD=ld                    \
#              --enable-languages=c,c++ \
#              --enable-default-pie     \
#              --enable-default-ssp     \
#              --enable-host-pie        \
#              --disable-nls            \
#              --disable-multilib       \
#              --disable-bootstrap      \
#              --disable-fixincludes    \
#              --with-system-zlib
# make
# make install

# LTO compatibility symlink
# ln -sfv ../../libexec/gcc/"$(gcc -dumpmachine)"/15.2.0/liblto_plugin.so \
#         /usr/lib/bfd-plugins/

# TODO: Match these with previous sanity checks
# Sanity checks

echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep 'Requesting program interpreter: /usr/lib/ld-linux-x86-64.so.2'

grep -Eo "/lib.*/S?crt[1in].*succeeded" dummy.log
grep -B4 '^ /usr/include' dummy.log
grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g'
grep "/lib.*/libc.so.6 " dummy.log | grep succeeded
grep found dummy.log | grep "/usr/lib/ld-linux-x86-64.so.2"
rm -vf a.out dummy.log

# Move a misplaced file
# mkdir -pv /usr/share/gdb/auto-load/usr/lib
# mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib


# # Gettext
# pre gettext
# ./configure --prefix=/usr       \
#             --disable-static    \
#             --disable-nls       \
#             --disable-rpath     \
#             --disable-acl       \
#             --without-git       \
#             --without-emacs     \
#             --without-bzip2     \
#             --without-selinux   \
#             --with-xz
# make
# make install
# chmod -v 755 /usr/lib/preloadable_libintl.so


# mkdir -pv /etc/default
# useradd -D --gid 999
# sed -i '/MAIL/s/yes/no/' /etc/default/useradd


# Cleanup
post
echo "Completed stage 3" >&2
echo "Cleaning up..."    >&2
sleep 2
cd /

# Remove temporary files
rm -rf {,/var}/tmp/*

# Remove lfstage artifacts
rm -rf /{tools,sources}
rm -vf /as_chroot.sh
rm -vf /build.env

# Remove documentation
rm -rf /usr/share/{man,info,doc}/*

# remove unused binaries and scripts
# TODO: Look into:
# - stty
# - sum
# - sha224sum, sha384sum
# - shred
# - script*
# - ptar*
# - pldd
# - csplit
_del=(
    base32
    bits # TODO: Figure out what even provides this lol
    chcon # selinux
    chmem
    choom
    chrt # this isn't a realtime system
    cksum
    corelist
    coresched
    cpan
    hexdump
    df
    dmesg # it isn't useful in a stage 2
    gawkbug
    gzexe
    instmodsh
    libnetcfg
    logname # similar to whoami, kinda useless
    look
    lsclocks
    lsfd
    lsipc
    lsirq
    lslogins
    lslocks
    lsns
    lto-dump # huge (42M) binary that I probably dont need
    namei
    nice
    nsenter
    pathchk
    perl{bug,thanks}
    piconv
    pipesz
    pr
    pydoc{,3}*
    renice # not needed in a stage 2
    runcon # selinux
    tzselect
    vdir
    wdctl
    xzcat
    xzcmp
    xzdiff
    xz*grep
    xzless
    sotruss
    xtrace
    zipdetails
    zcmp
    zdiff
    zdump
    z*grep
    zforce
    zless
    znew
)

# Remove unnecessary binaries
cd /usr/bin
rm -vf "${_del[@]}"
unset _del
cd /

# remove idle
rm -vf /usr/bin/idle3*
rm -rf /usr/lib/python3.*/idlelib

# remove stray readmes, batch scripts, and libtool archives
find / -type f \
    ! -path '/proc/*'           \
    \(                          \
        -iname 'readme*'        \
        -o -iname '*.bat'       \
        -o -iname '*.la'        \
    \)                          \
    -exec rm -vf {} +

# remove uncommon character encodings
# (utf8 is built into glibc)
find /usr/lib/gconv -type f     \
    -mindepth 1                 \
    ! -iname 'ISO8859-1.so'     \
    ! -iname 'UTF-16.so'        \
    ! -iname 'UTF-32.so'        \
    ! -iname 'gconv-modules*'   \
    -exec rm -vf {} +

# remove unused locales
find /usr/{share,lib}/locale    \
    -mindepth 1                 \
    -type d                     \
    ! -iname 'en_US*'           \
    ! -iname 'C.utf8'           \
    -exec rm -rvf {} +

# remove unused terminfo files
# find /usr/share/terminfo            \
#     -type f                         \
#     ! -path '*/l/linux'             \
#     ! -path '*/t/tmux'              \
#     ! -name '*/x/xterm-256color'    \
#     -exec rm -vf {} +
# find /usr/share/terminfo -type d -empty -delete

# mark success
touch /good
echo "Finished cleanup" >&2
