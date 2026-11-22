#!/usr/bin/env bash
# Local mirror of the CI build. Run on a Linux box with ~30 GB free.
# Usage: ./build-local.sh [/path/to/clang/bin]
# Default = KernelSU-Next only (KSU-only), matching the first green CI build.
# Set SUSFS=true to also apply the SUSFS patches (best-effort on non-GKI 4.19).
set -euo pipefail

KERNEL_REPO=https://github.com/oppo-source/android_kernel_oppo_mt6765
KERNEL_BRANCH=oppo/mt6765_t_13.1_oppo_a57_a57s_a77
# Vendor modules repo (same branch). Top-level is vendor/. The kernel tree's oplus
# symlinks come in two classes: ../../vendor/... and ../../../../vnd/vendor/... .
# Nesting the kernel at src/kernel makes both land inside this dir: src/vendor and
# vnd/vendor, both symlinked to the one real modules/vendor.
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

mkdir -p src vnd
[ -d src/kernel ] || git clone --depth 1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" src/kernel

# Overlay vendor modules. Kernel is nested at src/kernel; both oplus symlink classes
# (../../vendor and ../../../../vnd/vendor) resolve to src/vendor and vnd/vendor,
# both pointing at the one real modules/vendor.
[ -d modules ] || git clone --depth 1 -b "$KERNEL_BRANCH" "$MODULES_REPO" modules
[ -e src/vendor ] || ln -s "$HERE/modules/vendor" src/vendor
[ -e vnd/vendor ] || ln -s "$HERE/modules/vendor" vnd/vendor
# Oppo vendor drivers hardcode relative includes into a kernel dir named "kernel-4.19"
# (the stock build root). The quoted include resolves physically through the oplus
# symlink, landing inside modules/vendor, so alias kernel-4.19 -> the kernel root at the
# levels those climbs can land on.
for d in "$HERE" "$HERE/modules" "$HERE/modules/vendor"; do ln -sfn "$HERE/src/kernel" "$d/kernel-4.19"; done
test -f src/kernel/kernel/sched_assist/Kconfig
test -f src/kernel/drivers/base/kernelFwUpdate/Kconfig
test -f src/kernel/drivers/power/oplus/v1/adapter_ic/../charger_ic/../../../../../kernel-4.19/drivers/power/supply/charger_class.h

# KSU-Next pinned to v3.4.0-legacy: non-GKI 4.19 support AND KSU_VERSION 33294
# (30000 + 3005 commits + 289) <= manager v3.4.2 build 33355, so the manager matches.
[ -d src/kernel/KernelSU-Next ] || ( cd src/kernel && curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/legacy/kernel/setup.sh" | bash -s v3.4.0-legacy )

if [ "$SUSFS" = "true" ]; then
  [ -d susfs ] || git clone --depth 1 -b "$SUSFS_BRANCH" "$SUSFS_REPO" susfs
  cp susfs/kernel_patches/50_add_susfs_in_kernel-4.19.patch src/kernel/ || true
  cp -r susfs/kernel_patches/fs/* src/kernel/fs/ || true
  cp -r susfs/kernel_patches/include/linux/* src/kernel/include/linux/ || true
  ( cd src/kernel && patch -p1 < 50_add_susfs_in_kernel-4.19.patch || echo "WARN: SUSFS hunks failed; check *.rej" )
  cat config/ksu_susfs.config >> "src/kernel/arch/arm64/configs/$DEFCONFIG"
else
  cat config/ksu_only.config >> "src/kernel/arch/arm64/configs/$DEFCONFIG"
fi

export PATH="$CLANG_BIN:$PATH"
cd src/kernel
ARGS="O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LD=aarch64-linux-gnu-ld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip LLVM_IAS=0"
make $ARGS "$DEFCONFIG"
make -j"$(nproc)" $ARGS
ls -l out/arch/arm64/boot/
echo "Built. Pack with AnyKernel3 (see anykernel/anykernel.sh)."
