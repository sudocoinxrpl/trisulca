#!/usr/bin/env bash
# trisulca.bash – Build a hybrid BIOS+UEFI bootable Debian Live ISO or IMG,
# inject C++ toolchain + Secure Boot support + SudokuLinux branding + Calamares customization,
# and optionally QEMU-test it. Supports session resume via --workdir and --resume.
set -euo pipefail

##### Root-check #####
(( EUID == 0 )) || { echo "[ERROR] Run as root." >&2; exit 1; }

##### Defaults #####
WORKDIR="" MOUNTDIR="" CHROOTDIR="" LOOPDEV=""
WORKDIR_PROVIDED="false"
RESUME="false"
PATCHED_MARKER=".squashfs_patched"
CHROOT="${CHROOT:-/opt/sudobuild/chroot}"
TOOL="${TOOL:-/opt/os-theme-tool.bash}"

DOCKER_IMAGE=""


##### Cleanup on exit/interruption #####
cleanup() {
  echo "[CLEANUP] Unmounting…" >&2
  umount -lf /tmp/tmp.*                             2>/dev/null || true
  umount -lf "$CHROOTDIR"/{dev/pts,dev,proc,sys,run,tmp} 2>/dev/null || true
  umount -lf "$MOUNTDIR"                             2>/dev/null || true
  [[ -n "$LOOPDEV" ]] && losetup -d "$LOOPDEV"       2>/dev/null || true
  if [[ "$WORKDIR_PROVIDED" == "false" ]]; then
    rm -rf "$WORKDIR"
  fi
  echo "[CLEANUP] Done." >&2
}
trap cleanup EXIT INT TERM

##### Helpers #####
die(){ echo "[ERROR] $*" >&2; exit 1; }
log(){ echo "[INFO] $*"; }

##### Arg parsing #####
OUTPUT="" TESTFIRE="false"
(( $# >= 1 )) || die "Usage: $0 [--workdir dir] [--resume] [--testfire] [--output out.iso|out.img] [--docker-image name:tag] <input.iso>"
while (( $# )); do
  case "$1" in
    --workdir)  WORKDIR="$2"; WORKDIR_PROVIDED="true"; shift 2 ;;
    --resume)   RESUME="true"; shift ;;
    --testfire) TESTFIRE="true"; shift ;;
    --output|-o) OUTPUT="$2"; shift 2 ;;
    --docker-image|-d) DOCKER_IMAGE="$2"; shift 2 ;;
    --*)        die "Unknown option: $1" ;;
    *)          INPUT_ISO="$1"; shift ;;
  esac
done
[[ -f "$INPUT_ISO" ]] || die "Input ISO not found: $INPUT_ISO"


#dependency installation
sudo apt update
sudo apt install -y mtools xorriso isolinux syslinux-utils
sudo apt update



##### Derive WORKDIR/MOUNTDIR/CHROOTDIR #####
if [[ -z "$WORKDIR" ]]; then
  WORKDIR="$(mktemp -d)"
fi
MOUNTDIR="$WORKDIR/iso-mount"
CHROOTDIR="$WORKDIR/chroot"
mkdir -p "$MOUNTDIR" "$CHROOTDIR"

##### Derive output #####
if [[ -z "$OUTPUT" ]]; then
  base="${INPUT_ISO##*/}"
  OUTPUT="${base%.*}-custom.iso"
fi
case "$OUTPUT" in
  *.iso) OUT_MODE="iso" ;;
  *.img) OUT_MODE="img" ;;
  *)     die "Output must end in .iso or .img" ;;
esac

log "Input ISO:  $INPUT_ISO"
log "Output ($OUT_MODE): $OUTPUT"
log "Using WORKDIR: $WORKDIR (provided=$WORKDIR_PROVIDED, resume=$RESUME)"

##### Mount & copy ISO #####
if [[ "$RESUME" != "true" ]]; then
  log "Mounting input ISO…"
  mount -o loop,ro "$INPUT_ISO" "$MOUNTDIR" || die "mount failed"

  log "Copying ISO contents into iso-root…"
  ISO_ROOT="$WORKDIR/iso-root"
  rm -rf "$ISO_ROOT"
  mkdir -p "$ISO_ROOT"
  cp -a "$MOUNTDIR/." "$ISO_ROOT/" || die "copy failed"
  sync

  # Mirror out the live filesystem squashfs so downstream logic sees it in $WORKDIR/live
  mkdir -p "$WORKDIR/live"
  if [[ -f "$ISO_ROOT/live/filesystem.squashfs" ]]; then
    cp "$ISO_ROOT/live/filesystem.squashfs" "$WORKDIR/live/filesystem.squashfs"
  else
    die "Expected $ISO_ROOT/live/filesystem.squashfs not found"
  fi
else
  log "Resuming; skipping mount/copy"
  ISO_ROOT="$WORKDIR/iso-root"
fi

##### Branding assets #####
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#PLYMOUTH_SRC="$SCRIPT_DIR/sudoku/plymouth/sudoku"
BOOT_SPLASH_DIR="$SCRIPT_DIR/sudoku/grub"

##### Bootloader splash #####
log "Installing bootloader splash images…"
mkdir -p \
  "$WORKDIR/isolinux" "$WORKDIR/boot/grub" \
  "$ISO_ROOT/isolinux" "$ISO_ROOT/boot/grub"

cp "$BOOT_SPLASH_DIR/splash640.png" "$WORKDIR/isolinux/splash.png"
cp "$BOOT_SPLASH_DIR/splash800.png" "$WORKDIR/boot/grub/splash.png"
cp "$BOOT_SPLASH_DIR/splash640.png" "$ISO_ROOT/isolinux/splash.png"
cp "$BOOT_SPLASH_DIR/splash800.png" "$ISO_ROOT/boot/grub/splash.png"

##### Unsquash & patch live filesystem #####
SQUASHFS="$ISO_ROOT/live/filesystem.squashfs"

if [[ "$RESUME" != "true" || ! -f "$WORKDIR/$PATCHED_MARKER" ]]; then
  log "Clearing previous chroot content…"
  rm -rf "$CHROOTDIR"/* "$CHROOTDIR"/.[!.]* "$CHROOTDIR"/..?* || true

  log "Unsquashing $SQUASHFS…"
  unsquashfs -quiet -d "$CHROOTDIR" "$SQUASHFS" || die "unsquashfs failed"

  for fs in proc sys dev dev/pts run tmp; do
    mkdir -p "$CHROOTDIR/$fs"
    mount --bind "/$fs" "$CHROOTDIR/$fs" || die "failed to bind /$fs"
  done

  cp -L /etc/resolv.conf "$CHROOTDIR/etc/resolv.conf" 2>/dev/null || true

  log "Staging all /opt/sudoku assets into chroot…"
  mkdir -p "$CHROOTDIR/opt/sudoku"
  find "$SCRIPT_DIR/sudoku" -type f | while read -r src; do
    rel="${src#$SCRIPT_DIR/sudoku/}"
    dst="$CHROOTDIR/opt/sudoku/$rel"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  done









# Mount pseudo‑filesystems and drop to an interactive shell
# Mount pseudo‑filesystems and drop to an interactive shell
# Mount pseudo‑filesystems and drop to an interactive shell
#mount --bind /proc  "$CHROOTDIR/proc"
#mount --bind /sys   "$CHROOTDIR/sys"
#mount --bind /dev   "$CHROOTDIR/dev"
#mount --bind /dev/pts "$CHROOTDIR/dev/pts"

#echo "Entering chroot at $CHROOTDIR — run your debug commands, then exit to continue."
#chroot "$CHROOTDIR" /bin/bash --login





# Mount pseudo‑filesystems and drop to an interactive shell

# Mount pseudo‑filesystems and drop to an interactive shell

# Mount pseudo‑filesystems and drop to an interactive shell







chroot "$CHROOTDIR" bash -eux <<'CHROOT_IN'



cat > /etc/apt/sources.list.d/bookworm-backports.list <<EOF
deb http://deb.debian.org/debian bookworm-backports main
EOF

apt-get update
# Install the newer glibc and stdc++ from backports
apt-get install -y -t bookworm-backports \
libc6 libc6-dev libstdc++6 \
# (you can add libgcc-s1 libgcc-*-dev here if you need those too)
# then clean up
rm -rf /var/lib/apt/lists/*




# (re)create sources.list owned by root






#Dependency Install
####################################################
####################################################

#set apt repo-list
rm -f /etc/apt/sources.list
cp /opt/sudoku/apt/sources.list /etc/apt/sources.list
chown root:root /etc/apt/sources.list
apt-get update
apt-get source gnome-shell
sudo xargs -a /opt/sudoku/apt/apt.builddeps.list apt-get install -y
sudo xargs -a /opt/sudoku/apt/apt.minimal.list apt-get install -y --no-install-recommends
export DEBIAN_FRONTEND=noninteractive
apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false






#!/usr/bin/env bash
# sudoku-ui-setup.sh – Apply SudokuLinux UI customizations & dark style
set -euo pipefail

#disable plymouth
rm -f /usr/share/initramfs-tools/hooks/plymouth \
      /usr/share/initramfs-tools/scripts/init-bottom/plymouth


#################################
# UI Modifications & Dark Style
#################################

# 1) Copy & activate desktop-base theme (dark variant)
install -d /usr/share/desktop-base/sudoku-theme
cp -a /opt/sudoku/sudoku-theme/{lockscreen,wallpaper,login,metadata.json} \
      /usr/share/desktop-base/sudoku-theme/
ln -snf sudoku-theme /usr/share/desktop-base/active-theme
ln -snf dark        /usr/share/desktop-base/active-style

# 1a) Force GNOME itself into “dark” mode (GNOME 42+)
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-sudoku-darkmode <<'DCO_DARK'
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
DCO_DARK
dconf update

# B) GTK3 & GTK4 settings for other toolkits
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=true
EOF

mkdir -p /etc/gtk-4.0
cat > /etc/gtk-4.0/settings.ini <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=true
EOF

# also set the GNOME color-scheme key for the running session
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'


#################################
# 2) Lock-screen & login-screen
#################################
install -Dm644 \
  /opt/sudoku/gnome/lockscreen/sudokudelic.svg \
  /usr/share/backgrounds/gnome/sudokudelic.svg
chown root:root /usr/share/backgrounds/gnome/sudokudelic.svg
chmod 644    /usr/share/backgrounds/gnome/sudokudelic.svg

# dconf defaults for both lock-screen and login-screen
cat > /etc/dconf/db/local.d/00-sudoku-lockscreen <<'DCO_LOCK'
[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/gnome/sudokudelic.svg'
picture-options='zoom'

[org/gnome/login-screen]
logo='/usr/share/backgrounds/gnome/sudokudelic.svg'
DCO_LOCK
dconf update

# Fallback GLib overrides
install -Dm644 \
  /opt/sudoku/gnome/lockscreen/90_sudoku-lockscreen.gschema.override \
  /usr/share/glib-2.0/schemas/90_sudoku-lockscreen.gschema.override
install -Dm644 \
  /opt/sudoku/gnome/desktop_art/90_sudoku-background.gschema.override \
  /usr/share/glib-2.0/schemas/90_sudoku-background.gschema.override
glib-compile-schemas /usr/share/glib-2.0/schemas


#################################
# 3) GNOME desktop background
#################################
install -Dm644 \
  /opt/sudoku/gnome/desktop_art/sudoku4k.webp \
  /usr/share/backgrounds/gnome/sudoku4k.webp

cat > /etc/dconf/db/local.d/00-sudoku-background <<'DCO_BG'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/gnome/sudoku4k.webp'
picture-options='zoom'
DCO_BG
dconf update

cat > /usr/share/glib-2.0/schemas/90_sudoku-background.gschema.override <<'GSCHEMA_BG'
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/gnome/sudoku4k.webp'
picture-options='zoom'
GSCHEMA_BG
chmod 644 /usr/share/glib-2.0/schemas/90_sudoku-background.gschema.override
glib-compile-schemas /usr/share/glib-2.0/schemas


#################################
# 4) Plymouth theme
#################################
#install -d /usr/share/plymouth/themes/sudoku
#cp -a /opt/sudoku/plymouth/sudoku/. /usr/share/plymouth/themes/sudoku/

#update-alternatives --install \
#  /usr/share/plymouth/themes/default.plymouth default.plymouth \
#  /usr/share/plymouth/themes/sudoku/sudoku.plymouth 200

#plymouth-set-default-theme -R sudoku

#cat > /etc/plymouth/plymouthd.conf <<'EOF'
#[Daemon]
#Theme=sudoku
#ShowDelay=0
#EOF





update-initramfs -u
#plymouth-set-default-theme -R sudoku


#################################
# 5) Create user & set profile image
#################################
if ! id sudoku &>/dev/null; then
  useradd -m -s /bin/bash -G sudo sudoku
fi
echo 'sudoku:sudoku' | chpasswd




















#######################################################
# Calamares branding
#dock image
install -Dm644 /opt/sudoku/gnome/profile/sudoku-logo.png /usr/share/pixmaps/install-debian.png
install -d /etc/calamares/branding/sudoku
install -Dm644 /opt/sudoku/gnome/profile/sudoku-logo.png /etc/calamares/branding/sudoku/logo+sudoku.png
install -Dm644 /opt/sudoku/gnome/splash_assets/sudosplash.webp /etc/calamares/branding/sudoku/sudosplash.webp
#######################################################
# Calamares configuration injection
mkdir -p /usr/share/calamares/branding/sudoku/
cp /opt/sudoku/calamares/show.qml /usr/share/calamares/branding/sudoku
cp /opt/sudoku/calamares/settings.conf /etc/calamares/settings.conf
cp /opt/sudoku/calamares/branding.desc /usr/share/calamares/branding/sudoku/branding.desc
cp /opt/sudoku/plymouth/sudoku/logo+sudoku.png /usr/share/calamares/branding/sudoku/
#######################################################
#######################################################











#######################################################
# /# button
#######################################################

# sets activity button string
cd /tmp
mkdir -p gsbuild
cd gsbuild
# install build deps once
if ! dpkg -s debhelper-compat &>/dev/null; then
  apt-get update
  apt-get build-dep -y gnome-shell
fi
# fetch source only once
if ! ls gnome-shell-* 1> /dev/null 2>&1; then
  apt-get source gnome-shell
fi
# find the source dir
SRC_DIR="$(ls -d gnome-shell-* | head -n1)"
cd "$SRC_DIR"
# apply your patch
sed -i 's|^\([[:space:]]*text:[[:space:]]*_\)('\''Activities'\'')|\1('\''/#'\'')|' js/ui/panel.js
dpkg-buildpackage -us -uc -b
cd ..
dpkg -i gnome-shell_*.deb
cat > /etc/calamares/branding/sudoku/show.qml <<'SHOWQML'
import QtQuick 2.0
Rectangle {
    anchors.fill: parent
    color: "transparent"
    Image {
        id: splash
        source: "sudosplash.webp"
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectFit
    }
}
SHOWQML

#######################################################







































########################
# OS metadata
cat > /etc/os-release <<'REL'
NAME="SudokuLinux"
PRETTY_NAME="SudokuLinux"
ID=debian
VERSION_CODENAME=limestone
HOME_URL="https://sudokuous.org/"
SUPPORT_URL="https://sudokuous.org/support"
BUG_REPORT_URL="https://sudokuous.org/bugs"
REL

# Force the text theme as default (optional)
#update-alternatives --set default.plymouth /usr/share/plymouth/themes/text.plymouth

# Purge the plymouth runtime so nothing can re-invoke it
apt-get purge -y plymouth plymouth-theme-* --auto-remove
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
rm -rf /tmp/gsbuild /usr/src/* /root/.cache
apt-get purge -y dpkg-dev debhelper-compat build-essential gnome-control-center-dev \
gobject-introspection meson pkg-config sassc xvfb lib*-dev plymouth mutter libgtk-*-dev \
libgstreamer*-dev libmutter*-dev || true
apt-get autoremove -y && apt-get clean





# Purge plymouth so it cannot run in live
apt-get purge -y plymouth --auto-remove
rm -rf /usr/share/plymouth* /usr/bin/plymouth*



update-initramfs -u -k all
CHROOT_IN






# Repack the modified filesystem.squashfs
TMP_SQUASHFS="$WORKDIR/live/filesystem.squashfs"
rm -f "$TMP_SQUASHFS"

# Unmount any pseudo-filesystems so mksquashfs won’t spew symlink errors
for fs in proc sys dev/pts dev run tmp; do
  umount -lf "$CHROOTDIR/$fs" 2>/dev/null || true
done

/usr/bin/mksquashfs "$CHROOTDIR" "$TMP_SQUASHFS" \
    -noappend -comp xz \
    -e "proc/*" "sys/*" "dev/*" "dev/pts/*" "run/*" "tmp/*" \
  || die "mksquashfs failed"







# now overwrite the ISO’s live initrd with the new one
NEW_INIT=$(ls "$CHROOTDIR"/boot/initrd.img-*)
for OLD in "$ISO_ROOT"/live/initrd.img*; do
  cp "$NEW_INIT" "$OLD"
done







# Repack the modified filesystem.squashfs
TMP_SQUASHFS="$WORKDIR/live/filesystem.squashfs"
rm -f "$TMP_SQUASHFS"

# Unmount any pseudo-filesystems so mksquashfs won’t spew symlink errors
for fs in proc sys dev/pts dev run tmp; do
  umount -lf "$CHROOTDIR/$fs" 2>/dev/null || true
done

/usr/bin/mksquashfs "$CHROOTDIR" "$TMP_SQUASHFS" \
    -noappend -comp xz \
    -e "proc/*" "sys/*" "dev/*" "dev/pts/*" "run/*" "tmp/*" \
  || die "mksquashfs failed"

touch "$WORKDIR/$PATCHED_MARKER"

cp "$TMP_SQUASHFS" "$ISO_ROOT/live/filesystem.squashfs"

# disable plymouth in isolinux menus
for CFG in "$ISO_ROOT"/isolinux/{isolinux.cfg,live.cfg,txt.cfg}; do
  [[ -f "$CFG" ]] && sed -i '/append / s/$/ noplymouth/' "$CFG"
done

# strip plymouth hooks from live initrd images
log "strip plymouthd…"
shopt -s nullglob
for I in "$ISO_ROOT"/live/initrd.img*; do
  set +e
  gzip -t "$I" &>/dev/null && { DECOMP="gzip -dc"; COMP="gzip -c"; } ||
  xz   -t "$I" &>/dev/null && { DECOMP="xz -dc";   COMP="xz -c";   } ||
  lz4  -t "$I" &>/dev/null && { DECOMP="lz4 -dc";  COMP="lz4 -c";  } ||
  { DECOMP="cat"; COMP="gzip -c"; }
  rm -rf "$WORKDIR/initrd-tmp"
  mkdir -p "$WORKDIR/initrd-tmp"
  pushd "$WORKDIR/initrd-tmp" >/dev/null
    $DECOMP "$I" | cpio -idum --no-absolute-filenames
    CPIO_RC=$?
    if [[ $CPIO_RC -ne 0 ]]; then
      log "Skipping broken initrd: $I"
      popd >/dev/null
      continue
    fi
    rm -f usr/share/initramfs-tools/hooks/plymouth \
          usr/share/initramfs-tools/scripts/init-bottom/plymouth
    find . | cpio --create --format='newc' | $COMP > "$I"
  popd >/dev/null
  rm -rf "$WORKDIR/initrd-tmp"
  set -e
done
shopt -u nullglob

##### Ensure grub.cfg #####
GRUBCFG="$WORKDIR/boot/grub/grub.cfg"
if [[ ! -s "$GRUBCFG" ]]; then
  log "Generating grub.cfg..."
  mkdir -p "$(dirname "$GRUBCFG")"
  shopt -s nullglob
  {
    echo "set default=0"
    echo "set timeout=5"
    for kernel in "$WORKDIR"/live/vmlinuz-*; do
      ver="${kernel##*/vmlinuz-}"
      initrd="$WORKDIR/live/initrd.img-$ver"
      [[ -f "$initrd" ]] || initrd="$WORKDIR/live/initrd.img"
      echo "menuentry \"SudokuLinux Live ($ver)\" {"
      echo "  linux /live/vmlinuz-$ver boot=live noplymouth quiet"
      echo "  initrd /live/$(basename "$initrd")"
      echo "}"
    done
  } > "$GRUBCFG"
  shopt -u nullglob
fi

##### Validate workspace #####
log "Validating workspace files…"
[[ -f "$WORKDIR/isolinux/splash.png" ]] || die "isolinux splash missing"
[[ -f "$WORKDIR/boot/grub/splash.png"   ]] || die "grub splash missing"







##### Build final media #####
if [[ "$OUT_MODE" == "iso" ]]; then
  VOLID="$(blkid -p -s LABEL -o value "$INPUT_ISO" 2>/dev/null || echo "LIVE")-CUSTOM"
  EFI_IMG="$WORKDIR/boot/grub/efi.img" 
  
  # create a small FAT image for EFI/UEFI
  dd if=/dev/zero of="$EFI_IMG" bs=1M count=10 status=none
  mkfs.vfat "$EFI_IMG" >/dev/null  
  
  # prepare EFI stub
  mkdir -p "$WORKDIR/EFI/BOOT"
  [[ -f "$CHROOTDIR/usr/lib/shim/shimx64.efi.signed" ]] \
    && cp "$CHROOTDIR/usr/lib/shim/shimx64.efi.signed" "$WORKDIR/EFI/BOOT/BOOTX64.EFI"
  [[ -f "$CHROOTDIR/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed" ]] \
    && cp "$CHROOTDIR/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed" "$WORKDIR/EFI/BOOT/grubx64.efi" \
    || die "grubx64.efi.signed not found in chroot"
  # embed EFI image
  mmd -i "$EFI_IMG" ::EFI ::EFI/BOOT
  mcopy -i "$EFI_IMG" -sv "$WORKDIR/EFI/BOOT/BOOTX64.EFI" ::EFI/BOOT/
  mcopy -i "$EFI_IMG" -sv "$WORKDIR/EFI/BOOT/grubx64.efi" ::EFI/BOOT/

  # build the ISO, excluding the zoneinfo/right directory
  # ensure VOLID is uppercase, alphanumeric, max 16 chars
  VOLID="${VOLID^^}"
  VOLID="${VOLID//[^A-Z0-9]/_}"
  VOLID="${VOLID:0:16}"

# show squashfs sizes for debugging
ls -l "$WORKDIR/iso-root/live/filesystem.squashfs"

echo "[DBG] patched squashfs:"
ls -lh "$WORKDIR/live/filesystem.squashfs"
echo "[DBG] iso‑root squashfs:"
ls -lh "$WORKDIR/iso-root/live/filesystem.squashfs"





















# then proceed with xorriso repack…
xorriso -as mkisofs \
  -iso-level 3 \
  -r \
  -l \
  -V "$VOLID" \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -b isolinux/isolinux.bin -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -e "$(basename "$EFI_IMG")" -no-emul-boot \
  -isohybrid-gpt-basdat \
  --exclude '/usr/share/zoneinfo/right' \
  -o "$OUTPUT" "$WORKDIR/iso-root" \
|| die "xorriso failed"





  log "ISO created: $OUTPUT"
else
  size=$(du -s -B1 "$WORKDIR" | cut -f1)
  total=$((size + 500*1024*1024))
  (( total < 2147483648 )) && total=2147483648
  total=$(((total + 1048575)/1048576 * 1048576))
  truncate -s $total "$OUTPUT"
  parted --script "$OUTPUT" mklabel gpt \
    mkpart primary 1MiB 2MiB name 1 BIOS set 1 bios_grub on \
    mkpart primary fat32 2MiB 202MiB name 2 EFI set 2 esp on \
    mkpart primary ext4 202MiB 100% name 3 LIVE set 3 msftdata on || die "parted failed"

  LOOPDEV=$(losetup -f --show -P "$OUTPUT") || die "losetup failed"
  log "Loop device: $LOOPDEV"
  sleep 1 && udevadm settle

  mkfs.vfat -F32 "${LOOPDEV}p2" || die "mkfs.vfat failed"
  mkfs.ext4 -F "${LOOPDEV}p3" || die "mkfs.ext4 failed"

  mkdir -p "$WORKDIR/mnt_efi" "$WORKDIR/mnt_live"
  mount "${LOOPDEV}p3" "$WORKDIR/mnt_live"
  cp -a "$WORKDIR/." "$WORKDIR/mnt_live/"
  mount "${LOOPDEV}p2" "$WORKDIR/mnt_efi"
  mkdir -p "$WORKDIR/mnt_efi/EFI/BOOT"
  cp -f "$WORKDIR/EFI/BOOT/"* "$WORKDIR/mnt_efi/EFI/BOOT/" 2>/dev/null || true

  grub-install --target=x86_64-efi --efi-directory="$WORKDIR/mnt_efi" \
    --boot-directory="$WORKDIR/mnt_live/boot" --removable --no-nvram || die "grub-install (UEFI) failed"
  grub-install --target=i386-pc --boot-directory="$WORKDIR/mnt_live/boot" "$LOOPDEV" || die "grub-install (BIOS) failed"

  umount "$WORKDIR/mnt_efi" "$WORKDIR/mnt_live"
  losetup -d "$LOOPDEV"
  log "Disk image created: $OUTPUT"
fi



##### Optionally build Docker image from the customized live filesystem #####
if [[ -n "${DOCKER_IMAGE:-}" ]]; then
  log "Building Docker image 'sudocoin/sudoku:latest' from live filesystem"
  TMPDIR="$(mktemp -d)"
  unsquashfs -quiet -d "$TMPDIR" "$WORKDIR/live/filesystem.squashfs"

  log "Pruning unneeded packages and cleaning up rootfs…"
  chroot "$TMPDIR" bash -eux <<'CHROOT_CLEAN'
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y --auto-remove \
      build-essential g++ gcc cpp make git wget curl \
      --allow-change-held-packages || true
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/*
    rm -rf /lib/systemd /etc/systemd /usr/lib/systemd
    rm -rf /etc/cron* /var/spool/cron*
    rm -f /etc/ssh/ssh_host_*
    find /var/log -type f -exec truncate --size=0 {} \;
CHROOT_CLEAN

  log "Re-packing cleaned rootfs…"
  tar -C "$TMPDIR" -c . | docker import - sudocoin/sudoku:latest

  log "Pushing Docker image 'sudocoin/sudoku:latest'"
  docker push sudocoin/sudoku:latest

  rm -rf "$TMPDIR"
fi





##### Optional QEMU test #####
if [[ "$TESTFIRE" == "true" ]]; then
  log "Launching QEMU for test…"
  if [[ "$OUT_MODE" == "iso" ]]; then
    qemu-system-x86_64 -m 2048 -cdrom "$OUTPUT" -boot d &
  else
    qemu-system-x86_64 -m 2048 -hda "$OUTPUT" -boot c &
  fi
  log "QEMU launched; close when done."
fi

log "Build complete – enjoy your SudokuLinux live media!"
fi
