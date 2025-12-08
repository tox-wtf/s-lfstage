#!/usr/bin/bash

set -euo pipefail
# At this point, we're into stage 3 territory. This script is run as chroot. We
# don't actually build a stage 3 toolchain though.
#
# Packages:
# * Which           - Compilation convenience
# * Gettext-Tiny    - Minimal gettext implementation
# * Bison           - Dependency of Glibc
# * Iana-etc        - Nice to have
# * Zstd            - Needed by To
# * Zlib            - Dependency of Binutils
# * Pkgconf         - Compilation convenience


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
_:x:0:0:_:/home/_:/bin/bash
s:x:1000:1000:s builder:/home/s:/bin/bash
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
#!/usr/bin/env bash
type -pa "$@" | head -n1
exit ${PIPESTATUS[0]}
.


# Gettext-Tiny
pre gettext-tiny

make LIBINTL=NOOP
make LIBINTL=NOOP prefix=/usr install


# Bison
pre bison

./configure --prefix=/usr
make
make install


# Iana-etc
pre iana-etc
cp -vf services protocols /etc


# Glibc stuff
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
# NOTE: Zstd is built first to prevent it from including zlib support
pre zstd

make prefix=/usr
make prefix=/usr install
rm -vf /usr/lib/libzstd.a


# Zlib-ng
pre zlib-ng
./configure --prefix=/usr --shared --zlib-compat
make
make install


# Pkgconf
pre pkgconf
./configure --prefix=/usr --disable-static
make
make install
ln -sv pkgconf /usr/bin/pkg-config


# NASM
pre nasm

./configure \
            --disable-gc            \
            --disable-gdb           \
            --disable-debug         \
            --disable-profiling     \
            --disable-largefile     \
            --disable-panic-abort   \
            --disable-lto           \
            --disable-sanitizer     \
            --disable-suggestions
make PROGS=nasm
install -vDm755 nasm -t /usr/bin/


# tinaries
pre tinaries
make clear false reset true
make PREFIX=/usr install


# Binutils stuff
rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
        /usr/share/doc/gprofng/


# GCC stuff

# LTO compatibility symlink
ln -sfv ../../libexec/gcc/"$(gcc -dumpmachine)"/15.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/

# Perform some sanity checks
# NOTE: I've subtly tweaked the sanity checks to account for interpreter patching
echo "Performing sanity checks on glibc..."
echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep 'Requesting program interpreter: /usr/lib/ld-linux-x86-64.so.2'

grep -Eo "/lib.*/S?crt[1in].*succeeded" dummy.log
grep -B3 "^ /usr/include" dummy.log
grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g'
grep "/lib.*/libc.so.6 " dummy.log | grep succeeded
grep found dummy.log | grep "/usr/lib/ld-linux-x86-64.so.2"
rm -v a.out dummy.log

# Move a misplaced file
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib


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

# Remove toolchain binaries
# TODO: See if these are needed for stage 3 toolchain
rm -vf /usr/bin/x86_64-lfs-linux-gnu-*
rm -rf /usr/x86_64-lfs-linux-gnu

# remove unused binaries and scripts
_del=(
    bashbug
    bits # TODO: Figure out what even provides this lol
    bomtool
    captoinfo
    chmem
    choom
    chpasswd
    chroot
    chrt # this isn't a realtime system
    corelist
    coresched
    cpan
    hexdump
    df
    dmesg
    elfedit
    free
    fuser
    gawkbug
    gcov*
    getent
    gprof
    gzexe
    iconvconfig
    instmodsh
    libnetcfg
    look
    lsclocks
    lsfd
    lsipc
    lsirq
    lslogins
    lslocks
    lsns
    lspci
    lto-dump # huge (42M) binary that I probably dont need
    makedb
    mtrace
    namei
    nasm # only used to build tinaries
    nsenter
    pathchk
    pcprofiledump
    perl{bug,thanks}
    piconv
    pipesz
    pipe_progress
    pldd
    pydoc{,3}*
    renice # not needed in a stage 2
    sprof
    tzselect
    uevent
    watch
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
    zstdgrep
    zstdless
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
find /usr /var /etc -type f     \
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
find /usr/share/terminfo            \
    -type f                         \
    ! -path '*/l/linux'             \
    ! -path '*/t/tmux'              \
    ! -name '*/x/xterm-256color'    \
    -exec rm -vf {} +
find /usr/share/terminfo -type d -empty -delete

# mark success
touch /good
echo "Finished cleanup" >&2
