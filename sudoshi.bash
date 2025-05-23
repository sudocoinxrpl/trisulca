#!/usr/bin/env bash
#
# Usage: ./enter-chroot.sh /path/to/chroot
#
# Binds /proc, /sys, /dev and /dev/pts into the chroot, drops you into
# an interactive bash there, and then cleans up on exit.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <chroot-dir>"
  exit 1
fi

CHROOTDIR="$1"

# sanity check
if [[ ! -d "$CHROOTDIR" ]]; then
  echo "Error: '$CHROOTDIR' is not a directory."
  exit 2
fi

mount_bind() {
  local src=$1 dst=$2
  mkdir -p "$dst"
  mount --bind "$src" "$dst"
}

umount_if_mounted() {
  local target=$1
  if mountpoint -q "$target"; then
    umount -lf "$target"
  fi
}

cleanup() {
  echo "[cleanup] unmounting pseudo-filesystems..."
  umount_if_mounted "$CHROOTDIR/dev/pts"
  umount_if_mounted "$CHROOTDIR/dev"
  umount_if_mounted "$CHROOTDIR/sys"
  umount_if_mounted "$CHROOTDIR/proc"
}
trap cleanup EXIT INT TERM

echo "[info] mounting pseudo-filesystems into $CHROOTDIR..."
mount_bind /proc      "$CHROOTDIR/proc"
mount_bind /sys       "$CHROOTDIR/sys"
mount_bind /dev       "$CHROOTDIR/dev"
mount_bind /dev/pts   "$CHROOTDIR/dev/pts"

echo "[info] dropping into chroot at $CHROOTDIR"
chroot "$CHROOTDIR" /bin/bash --login

# when you exit the shell the trap will unmount everything
