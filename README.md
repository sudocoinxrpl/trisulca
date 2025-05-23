# trisulca.bash

##note for builders
#This script is not fully indemnotent yet, if it bails without a full cleanup youll need to reboot and delete any half baked chroots in your /tmp directory. Signs of this are sudo command not working correctly and running out of space errors





## installation

cd /opt/ && git clone https://github.com/sudocoinxrpl/trisulca.git

cp sudoku/trisulca .

chmod +x ./trisulca.bash

# see below for usage most can use something like this:
#  sudo '/opt/trisulca.bash' --docker-image sudocoin/sudoku:latest '/opt/debian-live-12.10.0-amd64-gnome.iso' --output sudoku-live-25.5.2-amd64-gnome.iso


















Build a hybrid BIOS+UEFI bootable Debian Live IMG with LVM-backed root, inject C++ toolchain + Secure Boot support + SudokuLinux branding + Calamares customization, and optionally QEMU-test it. Supports session resume via `--workdir` and `--resume`.

---

## Usage

Run the script as root, providing the input ISO and optional arguments:

```bash
sudo ./trisulca.bash [options] <input.iso>
```

### Options

- `--workdir <dir>`  
  Specify a working directory for temporary files (default: auto-generated temp directory).

- `--resume`  
  Resume a previous build from the specified `--workdir`.
  This is supposed to drop you off after the chroot and assumes a good chroot exists without handling
  

- `--testfire`  
  Launch QEMU to test the generated image after building.
  There is a block of commented code prior ot the chroot creation for stepping through the chroot

- `--output` / `-o <out.img>`  
  Specify the output file (must end in `.img`; default: derived from input ISO name).

- `--docker-image` / `-d <name:tag>`  
  Build and push a Docker image from the customized filesystem (e.g., `sudokulinux:latest`).

### Examples

**Basic IMG Build**  
```bash
sudo ./trisulca.bash debian-12.0.0-amd64-netinst.iso
```
Generates `debian-12.0.0-amd64-custom.img` with SudokuLinux customizations.

**Custom Output and QEMU Test**  
```bash
sudo ./trisulca.bash --output sudokulinux.img --testfire debian-12.0.0-amd64-netinst.iso
```
Creates `sudokulinux.img` and tests it in QEMU.

**Disk Image with Persistent Workdir**  
```bash
sudo ./trisulca.bash --workdir /tmp/sudoku-build --output sudokulinux.img debian-12.0.0-amd64-netinst.iso
```
Creates `sudokulinux.img` using `/tmp/sudoku-build` as the working directory.

**Resume Build and Docker Image**  
```bash
sudo ./trisulca.bash \
  --workdir /tmp/sudoku-build \
  --resume \
  --docker-image sudokulinux:latest \
  debian-12.0.0-amd64-netinst.iso
```
Resumes a build and creates a Docker image tagged `sudokulinux:latest`.

---

## Workflow

1. **Input Validation**  
   - Checks for root privileges and validates the input ISO presence.

2. **Workspace Setup**  
   - Creates or reuses a working directory.  
   - Mounts the input ISO and copies its contents.

3. **Filesystem Customization**  
   - Unsquashes the live filesystem into a chroot.  
   - Installs dependencies via custom APT lists.  
   - Applies SudokuLinux branding (GRUB, GNOME, Calamares, Plymouth).  
   - Configures dark mode, lockscreen, desktop background.  
   - Creates a `sudoku` user with default profile image.  
   - Modifies GNOME Shell’s Activities button text to `"/#"`.  
   - Updates `initramfs` and purges Plymouth.

4. **Repackaging**  
   - Rebuilds the squashfs filesystem.  
   - Updates GRUB configuration.  
   - **IMG path**: partitions disk image, sets up LVM root LV, installs BIOS+UEFI GRUB.  

5. **Optional Steps**  
   - Builds a Docker image from the customized filesystem (if `--docker-image` specified).  
   - Tests the output in QEMU (if `--testfire`).

6. **Cleanup**  
   - Unmounts only the script’s mounts, detaches loop devices, and deletes temp files (unless `--workdir` provided).

---

## Output

- **Disk Image (`.img`)**  
  A GPT-partitioned disk image containing BIOS and UEFI boot partitions and an LVM-backed live root filesystem.

- **Docker Image (optional)**  
  A container image based on the customized filesystem, stripped of build tools, caches, and unnecessary files.
  further logic to simplify the output's contents are needed this feature will not be supported much longer

---

## Notes

- **Root Privileges**: Required for mounting, chrooting, and disk operations.  
- **ISO Mode**: No longer supported for LVM-backed root; use `.img`.  
- **Plymouth**: Disabled in the live environment to avoid boot issues.  
- **Secure Boot**: Copies signed Shim and GRUB EFI binaries to ensure compatibility.  
- **Resume Feature**: Skip redundant work by reusing `--workdir`.  
- **Docker**: Docker image is optimized before import/push.

---

## Troubleshooting

- **“Input ISO not found”**: Ensure the specified ISO file exists and is readable.  
- **“mount failed”**: Check permissions and available loop devices (`losetup -a`).  
- **“mksquashfs failed”**: Verify disk space and that pseudo-filesystems are unmounted.  
- **QEMU Issues**: Ensure `qemu-system-x86_64` is installed and KVM support is enabled.  
- **Docker Errors**: Verify Docker is installed and you have push permissions.

---

## Contributing

Contributions are welcome! Please submit issues or pull requests to the repository. Ensure compatibility with Debian 12 and preserve idempotency and cleanup mechanisms.

---

## License

This project is licensed under the GPLv3 License. See the `LICENSE` file for details.

---

## Contact

For support, visit <https://https://x.com/sudocoinxrpl>
