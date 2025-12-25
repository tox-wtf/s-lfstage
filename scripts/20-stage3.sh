#!/bin/bash
set -euo pipefail # paranoia
# Build a stage 3 toolchain (calls ./libexec/as_chroot.sh)

# shellcheck disable=2086,2164,1091,2046

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Fix interpreters for all ELF files in $LFS/usr
echo "Patching interpreter for stragglers..."
find "$LFS/usr" -type f -executable | while read -r elf; do
    if file "$elf" | grep -qF ELF; then
        interp="$(patchelf --print-interpreter "$elf" 2>/dev/null || true)";
        if echo "$interp" | grep -qF "/lib64/ld-linux-x86-64.so.2"; then
            patchelf --set-interpreter "/usr/lib/ld-linux-x86-64.so.2" "$elf"
            printf "Patched interpreter for %s\n" "$elf"
        fi
    fi
done

# TODO: Add $SCRIPTS as a variable in lfstage instead of doing $SCRIPT_DIR
# shenanigans
cp -vf "$ENVS/build.env" "$LFS/build.env"
install -vm755 "$SCRIPT_DIR/libexec/as_chroot.sh" "$LFS/as_chroot.sh"

# TODO: See if /sys and /run should be created
# WARNING: Fun fact: bash will include '.' as an entry in $PATH if its empty,
# which breaks gcc because of course it does
bwrap \
    --bind "$LFS" /                         \
    --dev-bind /dev /dev                    \
    --proc /proc                            \
    --unshare-uts --hostname s-container    \
    --clearenv                              \
    --setenv TERM xterm-256color            \
    --setenv HOME /home/root                \
    --setenv PATH /usr/bin                  \
    --setenv MAKEFLAGS "-j$(nproc)"         \
    --chdir /                               \
    /as_chroot.sh

msg "Exited LFS chroot"

# Paranoia
if [[ ! -e "$LFS/good" ]]; then
    die "Detected a failure in LFS chroot"
fi

rm -vf "$LFS/good"
