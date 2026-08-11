cmd_libbb/makedev.o := aarch64-buildroot-linux-gnu-gcc -Wp,-MD,libbb/.makedev.o.d  -std=gnu99 -Iinclude -Ilibbb  -include include/autoconf.h -D_GNU_SOURCE -DNDEBUG -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -D_TIME_BITS=64 -DBB_VER='"1.37.0"' -Wall -Wshadow -Wwrite-strings -Wundef -Wstrict-prototypes -Wunused -Wunused-parameter -Wunused-function -Wunused-value -Wmissing-prototypes -Wmissing-declarations -Wno-format-security -Wdeclaration-after-statement -Wold-style-definition -finline-limit=0 -fno-builtin-strlen -fomit-frame-pointer -ffunction-sections -fdata-sections -fno-guess-branch-probability -funsigned-char -static-libgcc -falign-functions=1 -falign-jumps=1 -falign-labels=1 -falign-loops=1 -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-builtin-printf -Oz    -DKBUILD_BASENAME='"makedev"'  -DKBUILD_MODNAME='"makedev"' -c -o libbb/makedev.o libbb/makedev.c

deps_libbb/makedev.o := \
  libbb/makedev.c \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/stdc-predef.h \
  include/platform.h \
    $(wildcard include/config/werror.h) \
    $(wildcard include/config/big/endian.h) \
    $(wildcard include/config/little/endian.h) \
    $(wildcard include/config/nommu.h) \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/lib/gcc/aarch64-buildroot-linux-gnu/14.3.0/include/limits.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/lib/gcc/aarch64-buildroot-linux-gnu/14.3.0/include/syslimits.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/limits.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/libc-header-start.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/features.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/features-time64.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/wordsize.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/timesize.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/sys/cdefs.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/long-double.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/gnu/stubs.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/gnu/stubs-lp64.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/posix1_lim.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/local_lim.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/linux/limits.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/pthread_stack_min-dynamic.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/posix2_lim.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/xopen_lim.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/uio_lim.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/byteswap.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/byteswap.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/types.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/typesizes.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/time64.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/endian.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/endian.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/endianness.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/uintn-identity.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/lib/gcc/aarch64-buildroot-linux-gnu/14.3.0/include/stdint.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/stdint.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/wchar.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/stdint-intn.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/stdint-uintn.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/stdint-least.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/lib/gcc/aarch64-buildroot-linux-gnu/14.3.0/include/stdbool.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/unistd.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/posix_opt.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/environments.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/lib/gcc/aarch64-buildroot-linux-gnu/14.3.0/include/stddef.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/confname.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/getopt_posix.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/getopt_core.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/unistd_ext.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/sys/sysmacros.h \
  /home/dev/Projects/rpi5-custom-embedded-linux-platform/sdk/custom-sdk/aarch64-sdk/aarch64-buildroot-linux-gnu/sysroot/usr/include/bits/sysmacros.h \

libbb/makedev.o: $(deps_libbb/makedev.o)

$(deps_libbb/makedev.o):
