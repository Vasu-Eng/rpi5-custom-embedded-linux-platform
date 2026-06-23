# Dropbear SSH Bring-up Debugging Report

## Objective

Enable SSH login to the Raspberry Pi 5 initramfs image using Dropbear and key-based authentication.

## Initial Symptoms

The following issues were encountered during bring-up:

- `Connection refused`
- `Permission denied (publickey)`
- `User 'root' has invalid shell, rejected`
- `/root/.ssh must be owned by user or root, and not writable by group or others`

## Initramfs Ownership Issue During Packaging

### Problem

The SSH permission fix was correctly applied inside the rootfs tree:

```text
/root                 700
/root/.ssh            700
/root/.ssh/authorized_keys 600
```

However, after booting, ownership and permissions inside the target root filesystem were not always as expected.

During debugging, SSH authentication failed with:

```text
/root/.ssh must be owned by user or root, and not writable by group or others
```

### Root Cause

When creating an initramfs using `cpio`, file ownership information is stored inside the archive.

If the rootfs tree is packaged incorrectly, ownership may not match the expected:

```text
root:root
```

ownership on the target system.

### Correct Packaging Command

The initramfs must be generated using:

```bash
find . | cpio -H newc -ov --owner root:root > ../rootfs.cpio
```

Key option:

```text
--owner root:root
```

This forces all files stored inside the archive to have:

```text
UID = 0
GID = 0
```

regardless of the ownership on the host development machine.

### Compression

After creating the archive:

```bash
gzip -f ../rootfs.cpio
```

Result:

```text
rootfs.cpio.gz
```

### Verification

Verify important files are present before booting:

```bash
gzip -dc rootfs.cpio.gz | cpio -t | grep authorized_keys
```

```bash
gzip -dc rootfs.cpio.gz | cpio -t | grep shells
```

Expected output:

```text
root/.ssh/authorized_keys
etc/shells
```

### Lesson Learned

For embedded Linux initramfs development:

* File permissions alone are not sufficient.
* Ownership must also be correct.
* Always package using:

```bash
cpio --owner root:root
```

to guarantee consistent ownership on the target system.




## Investigation Steps

### 1. Confirmed network reachability
- Ethernet link came up successfully
- DHCP lease was obtained
- Static IP fallback was available

### 2. Confirmed Dropbear startup
- Dropbear server binary was present in the rootfs
- `dropbearmulti` was installed as the multi-call binary
- Dropbear was started from the init scripts

### 3. Verified authentication keys
- Host key was generated and packaged into `/etc/dropbear/dropbear_rsa_host_key`
- User public key was copied into `/root/.ssh/authorized_keys`
- Laptop private/public key pair matched the authorized key on the Pi


### 4. Fixed shell validation
Dropbear rejected login with:

`User 'root' has invalid shell, rejected`

Root cause:
- `/etc/shells` was missing from the initramfs

Fix:
- Added the following entries to `/etc/shells`:
  - `/bin/ash`
  - `/bin/sh`

### 5. Fixed permissions
Dropbear rejected login because `/root/.ssh` permissions were too open.

Fix:
- `chmod 700 /root`
- `chmod 700 /root/.ssh`
- `chmod 600 /root/.ssh/authorized_keys`

## Result

After applying the fixes, SSH login succeeded using public-key authentication.

## Key Lessons

- Trust Dropbear runtime logs.
- `authorized_keys` must exist in the booted initramfs, not only on the host.
- Root shell validation depends on `/etc/shells`.
- Directory ownership and permissions matter for SSH authentication.
- Initramfs content must be regenerated and repackaged after every rootfs change.
