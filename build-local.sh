#!/usr/bin/env bash
# Local mirror of the CI build. Run on a Linux box with ~30 GB free.
# Usage: ./build-local.sh [/path/to/clang/bin]
# Default = KernelSU-Next only (KSU-only), matching the first green CI build.
# Set SUSFS=true to also apply the SUSFS patches (best-effort on non-GKI 4.19).
set -euo pipefail

KERNEL_REPO=https://github.com/oppo-source/android_kernel_oppo_mt6765
KERNEL_BRANCH=oppo/mt6765_t_13.1_oppo_a57_a57s_a77
# Vendor modules repo (same branch). Top-level is vendor/. The kernel tree's oplus
# symlinks (kernel/sched_assist -> ../../vendor/oplus/...) resolve to <kernel>/vendor/...,
# so vendor/ must sit at the kernel repo root.
MODULES_REPO=https://github.com/oppo-source/android_kernel_modules_oppo_mt6765
DEFCONFIG=k65v1_64_bsp_defconfig
SUSFS_REPO=https://gitlab.com/simonpunk/susfs4ksu.git
SUSFS_BRANCH=kernel-4.19
SUSFS="${SUSFS:-false}"
HERE="$(cd "$(dirname "$0")" && pwd)"

CLANG_BIN="${1:-}"
if [ -z "$CLANG_BIN" ]; then
  echo "Provide clang bin dir (Android clang r383902 recommended). Download:"
  echo "  curl -LSs https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-11.0.0_r48/clang-r383902b.tar.gz | tar -xz -C clang"
  echo "  ./build-local.sh \$PWD/clang/bin"
  exit 1
fi

[ -d kernel ] || git clone --depth 1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" kernel

# Overlay vendor modules as a SIBLING of kernel/ so the ~89 oplus symlinks resolve.
# The links (e.g. kernel/sched_assist -> ../../vendor/oplus/...) resolve one level
# above the kernel tree root, i.e. to "$HERE/vendor".
if [ ! -d vendor ]; then
  [ -d modules ] || git clone --depth 1 -b "$KERNEL_BRANCH" "$MODULES_REPO" modules
  cp -a modules/vendor ./vendor
fi
test -f kernel/kernel/sched_assist/Kconfig

[ -d kernel/KernelSU-Next ] || ( cd kernel && curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s next )

if [ "$SUSFS" = "true" ]; then
  [ -d susfs ] || git clone --depth 1 -b "$SUSFS_BRANCH" "$SUSFS_REPO" susfs
  cp susfs/kernel_patches/50_add_susfs_in_kernel-4.19.patch kernel/ || true
  cp -r susfs/kernel_patches/fs/* kernel/fs/ || true
  cp -r susfs/kernel_patches/include/linux/* kernel/include/linux/ || true
  ( cd kernel && patch -p1 < 50_add_susfs_in_kernel-4.19.patch || echo "WARN: SUSFS hunks failed; check *.rej" )
  cat config/ksu_susfs.config >> "kernel/arch/arm64/configs/$DEFCONFIG"
else
  cat config/ksu_only.config >> "kernel/arch/arm64/configs/$DEFCONFIG"
fi

export PATH="$CLANG_BIN:$PATH"
cd kernel
ARGS="O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LD=aarch64-linux-gnu-ld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip LLVM_IAS=0"
make $ARGS "$DEFCONFIG"
make -j"$(nproc)" $ARGS
ls -l out/arch/arm64/boot/
echo "Built. Pack with AnyKernel3 (see anykernel/anykernel.sh)."
