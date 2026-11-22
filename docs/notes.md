# Build notes and decisions

## Toolchain
- Stock kernel built with Android clang r383902 (clang 11.0.1), read from the dumped `boot_a`
  Linux version string. CI fetches `clang-r383902b` from AOSP googlesource (android-11.0.0_r48)
  to match. If that tarball path 404s, swap `CLANG_URL` for another r383902 point (b/c) or a
  newer clang (12/14); 4.19 usually still builds, with warnings.
- `LLVM_IAS=0` (GNU assembler) + GNU binutils cross toolchains, because clang 11 / 4.19 MTK code
  does not assemble cleanly with the integrated assembler.

## KernelSU-Next
- `CONFIG_KPROBES=y` is already in the stock defconfig and arm64 selects HAVE_KPROBES /
  HAVE_KRETPROBES, so KSU-Next hooks via **kprobes** — we avoid the hard manual non-GKI syscall
  hooks that SUSFS's README describes for kernels without kprobes.

## SUSFS (the fragile part)
- SUSFS only supports KernelSU/KernelSU-Next, not APatch.
- `kernel-4.19` branch last updated 2025-02-23; GKI branches are far newer. Non-GKI SUSFS is
  explicitly "no guarantee it works out of the box."
- The `50_add_susfs_in_kernel-4.19.patch` may have failed hunks against this exact tree. The
  workflow continues and uploads `*.rej`; fix those by hand and re-run.
- KSU-Next may already bundle SUSFS support, so `10_enable_susfs_for_ksu.patch` can conflict;
  it is applied best-effort and is non-fatal.

## Device specifics
- Monolithic boot (header v2), so AnyKernel3 targets `block=boot` with `is_slot_device=1` (A/B).
  There is no `vendor_boot`/`init_boot` to touch.
- Project id 21334; board dts likely `oplus6765_21333`. Not needed for a pure kernel build
  (defconfig + appended dtb cover it).

## If the build fails
1. Toolchain fetch 404 -> change `CLANG_URL`.
2. SUSFS hunks fail -> read `*.rej`, patch manually, commit, re-run.
3. Image not produced -> read `build.log`; usually a config or assembler error.
4. Boots but bootloops after flash -> restore stock `boot` from the private backup.
