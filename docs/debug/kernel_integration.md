# Custom Kernel Integration - Raspberry Pi 5

## Objective

Integrate a custom-built Linux kernel into a minimal BusyBox-based Linux image for Raspberry Pi 5 while maintaining a reproducible BSP deployment workflow.

---

# Repository

## Kernel Source

```
linux-rpi-custom
```

Branch:

```
rpi-6.18.y
```

## Platform Repository

```
rpi5-custom-embedded-linux-platform
```

---

# Build Environment

Host OS:

```
Ubuntu 24.04 LTS
```

Target Architecture:

```
ARM64 (AArch64)
```

Cross Compiler:

```
aarch64-linux-gnu-gcc
```

---

# Kernel Build

Kernel is built using:

```bash
make -j$(nproc) \
ARCH=arm64 \
CROSS_COMPILE=aarch64-linux-gnu- \
Image modules dtbs
```

Generated artifacts:

```
arch/arm64/boot/Image
arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb
arch/arm/boot/dts/overlays/
```

---

# Deployment

Deployment is fully automated using:

```
scripts/deploy_kernel.sh
```

The deployment script performs the following tasks:

1. Compresses the generated kernel (`Image` → `Image.gz`).
2. Copies the compressed kernel into the boot filesystem.
3. Renames the kernel as:

```
rpi5_custom_minimal_kernel.img.gz
```

4. Copies the Raspberry Pi 5 Device Tree Blob:

```
bcm2712-rpi-5-b.dtb
```

5. Synchronizes the complete Device Tree overlay directory using `rsync`.

6. Verifies deployment by comparing the SHA-256 hash of the source and deployed kernel images.

---

# Boot Filesystem Layout

```
rpi_bootfs/
├── cmdline.txt
├── config.txt
├── bcm2712-rpi-5-b.dtb
├── overlays/
├── rootfs.cpio.gz
└── rpi5_custom_minimal_kernel.img.gz
```

---

# Boot Configuration

`config.txt`

```ini
[all]
enable_uart=1
uart_2ndstage=1

[pi5]
arm_64bit=1
kernel=rpi5_custom_minimal_kernel.img.gz
device_tree=bcm2712-rpi-5-b.dtb
initramfs rootfs.cpio.gz followkernel
```

---

# Deployment Verification

The deployment script verifies that the copied kernel image is identical to the generated kernel by comparing SHA-256 hashes.

Example:

```
Source   : d1f7c7bcb3...
Deployed : d1f7c7bcb3...

✓ Kernel integrity verification PASSED.
```

This ensures the deployed boot image exactly matches the kernel produced by the build system.

---

# Current Validation

Successfully verified:

- Custom ARM64 kernel boots successfully.
- BusyBox userspace initializes correctly.
- Custom Device Tree Blob loads successfully.
- Device Tree overlays are deployed correctly.
- SPI subsystem initializes successfully.
- `spidev` driver is registered.
- SPI master subsystem is operational.
- ILI9341 driver is available in the kernel.

Observed:

```
/sys/class/spi_master/
└── spi10
```

```
/sys/bus/spi/drivers/

ili9341
spidev
stmpe-spi
```

Current investigation indicates that the RP1 SPI0 controller remains disabled in the base Device Tree (`status = "disabled"`). Future work will enable SPI0 for the Raspberry Pi 40-pin expansion header.

---

# Next Development Steps

- Enable RP1 SPI0 in the Device Tree.
- Validate SPI0 enumeration on the 40-pin header.
- Integrate ILI9341 LCD using Device Tree.
- Configure DRM and framebuffer console.
- Display Linux kernel boot messages on the SPI LCD.
- Implement complete LCD bring-up and userspace validation.

---

# Key Learning Outcomes

During this milestone the following Linux BSP concepts were explored:

- Linux kernel cross compilation
- ARM64 kernel image generation
- Device Tree Blob (DTB) generation
- Device Tree Overlay (DTBO) management
- Raspberry Pi boot flow
- Boot firmware configuration (`config.txt`)
- Kernel deployment automation
- SHA-256 deployment verification
- SPI subsystem initialization
- Linux Device Tree investigation
- RP1 peripheral architecture on Raspberry Pi 5
