# Password Authentication in BusyBox Embedded Linux

## Overview

Before enabling remote access using Dropbear SSH, local password authentication should be verified.

Linux authentication typically uses three files:

```text
/etc/passwd
/etc/group
/etc/shadow
```

BusyBox `login` reads these files to authenticate users.

---

## User Database - /etc/passwd

Example:

```text
root:x:0:0:root:/root:/bin/ash
```

Fields:

```text
username:password:UID:GID:comment:home:shell
```

Description:

| Field    | Value    | Meaning                        |
| -------- | -------- | ------------------------------ |
| username | root     | Login name                     |
| password | x        | Password stored in /etc/shadow |
| UID      | 0        | User ID                        |
| GID      | 0        | Primary Group ID               |
| comment  | root     | Description                    |
| home     | /root    | Home directory                 |
| shell    | /bin/ash | Login shell                    |

---

## Group Database - /etc/group

Example:

```text
root:x:0:
```

Fields:

```text
groupname:password:GID:members
```

Description:

| Field     | Value | Meaning                    |
| --------- | ----- | -------------------------- |
| groupname | root  | Group name                 |
| password  | x     | Group password placeholder |
| GID       | 0     | Group ID                   |
| members   | empty | Additional group members   |

### Why No UID?

Groups represent collections of users.

A single group may contain multiple users:

```text
developers:x:1000:alice,bob,charlie
```

Therefore groups use a GID, not a UID.

---

## Shadow Password Database - /etc/shadow

Example:

```text
root:$6$HASH_HERE:20626:0:99999:7:::
```

Fields:

```text
username:hash:lastchg:min:max:warn:inactive:expire:reserved
```

Description:

| Field    | Value  | Meaning                             |
| -------- | ------ | ----------------------------------- |
| username | root   | Login user                          |
| hash     | $6$... | Password hash                       |
| lastchg  | 20626  | Days since Jan 1, 1970              |
| min      | 0      | Minimum days before password change |
| max      | 99999  | Password validity period            |
| warn     | 7      | Warning before expiry               |

For embedded systems:

```text
20626:0:99999:7:::
```

is commonly used and effectively means the password never expires.

---

## Password Hash Generation

Passwords are never stored in plaintext.

Example:

```text
embedded123
```

is stored as:

```text
$6$abc123$xxxxxxxxxxxxxxxxxxxx
```

### Generate SHA-512 Hash Using OpenSSL

Interactive:

```bash
openssl passwd -6
```

Direct:

```bash
openssl passwd -6 embedded123
```

Example Output:

```text
$6$Q2Yt4xLz4jJ6xj8m$V4P6...
```

---

## Example Authentication Files

### /etc/passwd

```text
root:x:0:0:root:/root:/bin/ash
```

### /etc/group

```text
root:x:0:
```

### /etc/shadow

```text
root:$6$HASH_HERE:20626:0:99999:7:::
```

---

## File Permissions

```bash
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 600 /etc/shadow
```

Verification:

```bash
ls -l /etc/passwd /etc/group /etc/shadow
```

Expected:

```text
-rw-r--r-- passwd
-rw-r--r-- group
-rw------- shadow
```

---

## BusyBox Requirements

Authentication requires BusyBox to be built with:

```text
CONFIG_LOGIN=y
CONFIG_FEATURE_SHADOWPASSWDS=y
```

Verification:

```bash
busybox | grep login
```

Expected:

```text
login
```

---

## Planned Integration

Current boot flow:

```text
Kernel
 └── /init
      └── BusyBox init
            └── cttyhack
                  └── ash
```

Target boot flow:

```text
Kernel
 └── /init
      └── BusyBox init
            └── login
                  └── password authentication
                        └── ash
```

After local password authentication is verified, Dropbear SSH integration can be added.
