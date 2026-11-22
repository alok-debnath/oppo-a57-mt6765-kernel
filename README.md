# Oppo A57 4G (CPH2387 / MT6765) — custom kernel

Builds a **KernelSU-Next + SUSFS** kernel for the Oppo A57 4G (CPH2387, device `OP5355`,
MediaTek Helio G35 / MT6765, Android 13 / ColorOS 13.1). Output is an **AnyKernel3** flashable
zip that swaps only the kernel in the live `boot` partition.

> Public repo on purpose: public repos get **unlimited free GitHub Actions minutes**. The kernel
> source is Oppo's GPL release; nothing device-identifying or personal is stored here.

## Facts this build is pinned to

| Item | Value |
|---|---|
| Kernel source | `oppo-source/android_kernel_oppo_mt6765` |
| Branch | `oppo/mt6765_t_13.1_oppo_a57_a57s_a77` |
| Kernel version | 4.19.191 (non-GKI, monolithic boot hdr v2) |
| Defconfig | `k65v1_64_bsp_defconfig` |
| Stock compiler | Android clang **r383902** (clang 11.0.1) — matched in CI |
| Root | KernelSU-Next via **kprobe hooks** (`CONFIG_KPROBES=y`, no manual hooks) |
| Hiding | SUSFS `kernel-4.19` branch (best-effort; see notes) |

## Build

- **GitHub Actions:** Actions tab → "Build kernel" → Run workflow. Artifact `kernel-build`
  contains the AnyKernel3 zip, raw `Image*`, `build.log`, and any `*.rej` (failed patch hunks).
- **Locally:** `./build-local.sh /path/to/clang-r383902/bin` (needs ~30 GB free).

## Flash (after bootloader unlock + a root method present)

The AnyKernel3 zip replaces the kernel inside `boot`. Flash via a custom recovery, or via the
KernelSU/APatch manager's "install from zip", or with `fastboot`/mtkclient after repacking.
Keep your stock `boot` backup — if it bootloops, restore `boot` from the backup.

## Status / honesty

Non-GKI 4.19 + SUSFS is fragile (upstream warns patches may need manual fixups). The first CI run
may fail on the SUSFS patch or the toolchain; that is expected. The workflow keeps going past
failed SUSFS hunks and uploads `*.rej` so they can be fixed. KernelSU-Next alone (kprobe hooks)
is the more certain part; SUSFS is the stretch. See `docs/notes.md`.

Related private repo (backup, unlock, device data): not linked here on purpose.
