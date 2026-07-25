# SPI0 Controller Bring-up Investigation

> Project: Custom Embedded Linux BSP for Raspberry Pi 5
>
> Author: Vasudev Kesharwani
>
> Status: ✅ Completed
>
> Target Board: Raspberry Pi 5
>
> Operating System: Custom BusyBox Linux
>
> Architecture: ARM64
>
> Kernel: Linux
>
> Date: July 2026

---

# Table of Contents

1. Objective
2. Background
3. Raspberry Pi 5 Architecture
4. Linux SPI Architecture
5. Investigation Timeline
6. Device Tree Investigation
7. Firmware Investigation
8. Driver Investigation
9. Driver Binding Verification
10. SPI Framework Verification
11. Final Verification
12. Conclusion
13. Next Phase

---

# 1. Objective

The objective of this investigation was to bring up the SPI0 controller on a custom Embedded Linux image built from scratch without using Yocto or Buildroot.

The SPI controller is required for future peripherals including:

- 3.5" SPI LCD
- SPI Flash
- Touchscreen Controller
- Sensors

Before bringing up any SPI peripheral, the SPI controller itself must be fully operational.

---

# 2. Background

Unlike Raspberry Pi OS, this project uses a completely custom Linux system consisting of

- Raspberry Pi Firmware
- Linux Kernel
- BusyBox RootFS
- Dropbear SSH

Since this image was built from scratch, every hardware peripheral must be verified individually.

The SPI subsystem was selected as the first hardware bring-up target.

---

# 3. Raspberry Pi 5 SPI Architecture

```

```
                    Raspberry Pi 5

                 +---------------------+
                 |      BCM2712        |
                 +----------+----------+
                            |
                         PCIe Link
                            |
                            ▼
                 +---------------------+
                 |        RP1          |
                 +---------------------+
                 | UART                |
                 | GPIO                |
                 | I2C                 |
                 | SPI0                |
                 | SPI1                |
                 | SPI2                |
                 | PWM                 |
                 +---------------------+
```

The SPI controller used by the GPIO header is located inside the RP1 chip.

---

# 4. Linux SPI Architecture

```

```
Application
      │
      ▼
spidev
      │
      ▼
SPI Framework
      │
      ▼
SPI Controller Driver
(dw_spi_mmio)
      │
      ▼
SPI Controller Hardware
(RP1 SPI0)
      │
      ▼
SPI Bus
      │
      ▼
External Device
```

---

# 5. Investigation Timeline

## Initial State

BusyBox booted successfully.

Known:

- Linux boots
- UART works
- Network works

Unknown:

- SPI Controller
- SPI Driver
- Device Tree
- Driver Binding

---

# 6. Device Tree Investigation

The SPI controller node was located inside the Device Tree.


```dts
spi@50000 {
    compatible = "snps,dw-apb-ssi";
    status = "disabled";
};
```

Initially the controller appeared to be disabled.

The first assumption was that enabling

```dts
status = "okay";
```

would automatically enable SPI.

This assumption was incorrect.

Further investigation was required.

---

# 7. Running Device Tree Investigation

The running Device Tree was extracted from Linux.

Unexpectedly the running system contained

```dts
status = "okay";
```

while the source DTB contained

```dts
status = "disabled";
```

This indicated that something modified the Device Tree before Linux booted.

---

# 8. Firmware Investigation

Firmware logs were inspected.

The firmware reported

```
Loaded overlay bcm2712d0
Loaded overlay sunfounder-pironman5
Loaded overlay vc4-kms-v3d-pi5
```

Conclusion:

The Raspberry Pi firmware applies overlays before passing the final Device Tree to Linux.

Final boot flow

```

```
Base DTB
      │
      ▼
Firmware
      │
      ▼
Apply Overlays
      │
      ▼
Merged Device Tree
      │
      ▼
Linux Kernel
```

---

# 9. Linux Driver Investigation

The Device Tree contains

```dts
compatible = "snps,dw-apb-ssi";
```

During boot Linux searches all registered platform drivers.

The matching driver is

```
drivers/spi/spi-dw-mmio.c
```

This driver registers

```
dw_spi_mmio_probe()
```

When a compatible string matches, Linux calls the driver's probe() function.

---

# 10. Kernel Rebuild for SPI Support

During the SPI bring-up investigation it was discovered that the required
SPI controller drivers were compiled as loadable kernel modules (`=m`).

On a standard Linux distribution this is not an issue because the root
filesystem contains the required modules and userspace automatically loads
them during boot.

However, this project uses a minimal BusyBox-based root filesystem where
kernel modules were intentionally omitted.

As a result, the SPI controller driver was never loaded even though the
Device Tree correctly described the hardware.

---

## Investigation

The running kernel configuration showed that the DesignWare SPI drivers
were configured as modules.

Typical configuration

```text
CONFIG_SPI_DW=m
CONFIG_SPI_DW_MMIO=m
CONFIG_SPI_SPIDEV=m
```

Without these modules being available inside the root filesystem,
Linux could not initialize the SPI controller.

---

## Solution

Rather than copying kernel modules into the BusyBox root filesystem,
the kernel was rebuilt with the required SPI drivers compiled directly
into the kernel image.

Updated configuration

```text
CONFIG_SPI_DW=y
CONFIG_SPI_DW_MMIO=y
CONFIG_SPI_SPIDEV=y
```

Building the drivers into the kernel simplifies early hardware bring-up
and removes the dependency on module loading.

This approach is commonly used during BSP development and board bring-up.

---

## Kernel Source

The modified Raspberry Pi Linux kernel used for this project is maintained
in the following repository:

```text
https://github.com/Vasu-Eng/linux-rpi-custom
```

commit :

```text
https://github.com/raspberrypi/linux/commit/83e678beb542c4fa2f4c60969cc735056a328877
```

---

## Build Process

The kernel was rebuilt after updating the configuration.

```bash
make menuconfig

make -j$(nproc)

make modules

make dtbs
```

The newly generated kernel image and Device Tree blobs were copied to the
boot partition of the Raspberry Pi.

After rebooting, the SPI controller driver was initialized automatically
during kernel startup.

---

## Verification

Successful driver loading was verified using

```bash
readlink -f /sys/class/spi_master/spi0/device/driver
```

Output

```text
/sys/bus/platform/drivers/dw_spi_mmio
```

This confirmed that

- the rebuilt kernel included the required SPI drivers,
- Linux successfully matched the Device Tree,
- the SPI controller was initialized during boot, and
- the SPI Master was registered successfully.

# 11. Driver Binding Verification

The following command was executed

```bash
readlink -f /sys/class/spi_master/spi0/device/driver
```

Output

```text
/sys/bus/platform/drivers/dw_spi_mmio
```

This verifies that

- Linux found the correct driver
- Driver successfully matched the Device Tree
- probe() executed successfully
- SPI controller initialized

---

# 12. SPI Master Verification

Command

```bash
ls /sys/class/spi_master
```

Output

```text
spi0
```

Meaning

```
Driver

↓

probe()

↓

spi_register_controller()

↓

spi0
```

The SPI controller has been successfully registered.

---

# 13. Device Tree Child Nodes

Inspection

```bash
ls /sys/class/spi_master/spi0/device/of_node
```

Result

```
spidev@0
spidev@1
```

Meaning

Linux correctly parsed the Device Tree child nodes.

---

# 14. SPI Device Verification

Command

```bash
ls /dev | grep spidev
```

Output

```text
spidev0.0
spidev0.1
spidev10.0
```

Meaning

The generic SPI device driver successfully created character devices.

```
spidev0.0

↓

SPI Bus 0

↓

Chip Select 0
```

```
spidev0.1

↓

SPI Bus 0

↓

Chip Select 1
```

---

# 15. Complete Linux SPI Bring-up Flow

```

```
Bootloader
      │
      ▼
Linux Kernel
      │
      ▼
Read Device Tree
      │
      ▼
spi@50000
      │
compatible = "snps,dw-apb-ssi"
      │
      ▼
Platform Device Created
      │
      ▼
Driver Search
      │
      ▼
dw_spi_mmio
      │
      ▼
probe()
      │
      ▼
Initialize Hardware
      │
      ▼
spi_register_controller()
      │
      ▼
spi0
      │
      ▼
Read Child Nodes
      │
      ▼
spidev Driver
      │
      ▼
/dev/spidev0.0
/dev/spidev0.1
```

---

# 16. Verification Checklist

| Component | Status |
|-----------|--------|
| BusyBox Boot | ✅ |
| Device Tree Loaded | ✅ |
| SPI Node Enabled | ✅ |
| Driver Matched | ✅ |
| probe() Successful | ✅ |
| SPI Controller Initialized | ✅ |
| SPI Master Created | ✅ |
| Device Tree Parsed | ✅ |
| spidev Created | ✅ |

---

# 17. Lessons Learned

## SPI Controller

The SPI Controller is hardware located inside RP1.

---

## SPI Controller Driver

The SPI Controller Driver is Linux software responsible for controlling the hardware.

---

## SPI Master

The SPI Master is the Linux representation of the SPI controller after successful driver initialization.

---

## spidev

spidev is a generic userspace SPI driver.

It is **not** the SPI controller driver.

---

# 18. Conclusion

The SPI0 controller bring-up is complete.

The Linux kernel successfully

- parsed the Device Tree
- matched the SPI controller driver
- executed probe()
- initialized SPI hardware
- registered SPI Master
- created generic SPI devices

The SPI subsystem is fully operational.

---

# 19. Next Phase

The next phase of this BSP project is

# LCD Bring-up

The generic Device Tree node

```dts
spidev@0
```

will be replaced with

```dts
display@0
```

The Linux LCD driver will then initialize the SPI display during boot.

This marks the transition from **SPI Controller Bring-up** to **SPI Peripheral Bring-up**.


# Conclusion

The SPI0 controller bring-up has been successfully completed and verified.

The following have been confirmed:

- Device Tree parsed correctly
- SPI controller driver (`dw_spi_mmio`) bound successfully
- `probe()` executed
- SPI Master registered
- Generic SPI devices created
- Userspace can access `/dev/spidev0.0` and `/dev/spidev0.1`

This milestone establishes a fully functional SPI subsystem on the custom BusyBox Linux image.

The next stage of the project—bringing up an SPI LCD—is documented in:

`02-lcd-bringup-roadmap.md`
