build.sh custom-sdk
        │
        ▼
Find SDK tarball
        │
        ▼
Is aarch64-sdk already present?
        │
     ┌──┴───┐
    NO     YES
    │       │
    │       ▼
    │   Read stored SHA256
    │       │
    │       ▼
    │   Calculate tarball SHA256
    │       │
    │    ┌──┴─────┐
    │   SAME    DIFFERENT
    │    │          │
    │    ▼          ▼
    │  "SDK      Ask:
    │   already   overwrite? [y/N]
    │   current"     │
    │               ├── N → exit
    │               └── Y → remove + extract
    ▼
extract SDK
    │
    ▼
store SHA256
    │
    ▼
source environment-setup


sdk/
├── environment-setup
├── official-sdk/
│   ├── aarch64-buildroot-linux-gnu_sdk-buildroot.tar.gz   # Downloaded
│   │                                                                                             │   ├── .sdk-sha256                                        # Tarball SHA256
│   └── aarch64-sdk/
│       └── aarch64-buildroot-linux-gnu/
│           └── sysroot/
└── custom-sdk/
    ├── buildroot-toolchains/
    │   └── output/
    │       └── images/
    │           └── aarch64-buildroot-linux-gnu_sdk-buildroot.tar.gz
    
    ├── .sdk-sha256
    └── aarch64-sdk/
        └── aarch64-buildroot-linux-gnu/
            └── sysroot/


