# Build log and working recipe — Oppo A57 4G (CPH2387, MT6765, non-GKI Linux 4.19)

This is the detailed troubleshooting log. `docs/notes.md` is the quick reference.
The CI entry point is `.github/workflows/build.yml`; `build-local.sh` mirrors it.

## Sources

- Kernel: `oppo-source/android_kernel_oppo_mt6765`, branch
  `oppo/mt6765_t_13.1_oppo_a57_a57s_a77`, defconfig `k65v1_64_bsp_defconfig`.
- Vendor modules: `oppo-source/android_kernel_modules_oppo_mt6765`, SAME branch.
  Its top level is `vendor/` (contains `vendor/mediatek` and `vendor/oplus`).

## The vendor symlink / nested-layout requirement

The kernel tree carries ~89 git symlinks (mode 120000) whose content is not in the
kernel repo — it lives in the vendor modules repo under `vendor/oplus/...`. The stock
Oppo/MTK build overlays both repos. The symlink targets come in two classes:

| Symlink example | Target | Resolves to |
| --- | --- | --- |
| `kernel/sched_assist` | `../../vendor/oplus/kernel/oplus_performance/sched_assist/` | one level **above** the kernel root |
| `drivers/base/kernelFwUpdate` | `../../../../vnd/vendor/oplus/kernel/touchpanel/kernelFwUpdate/` | two levels **above** the kernel root, under `vnd/vendor` |

Both classes want the SAME content (the modules repo's `vendor/`). There is no
separate `vnd` repo. To make both land inside `$GITHUB_WORKSPACE`, nest the kernel at
`src/kernel` and provide two symlinks to the single real `modules/vendor`:

```
$GITHUB_WORKSPACE/
  modules/vendor/...                 # clone of the modules repo (the real content)
  src/kernel/                        # KROOT: the kernel source
  src/vendor  -> modules/vendor      # satisfies ../vendor  (class 1)
  vnd/vendor  -> modules/vendor      # satisfies ../../vnd/vendor (class 2)
```

Exact commands (see the workflow for the authoritative copy):

```sh
git clone --depth 1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" src/kernel
git clone --depth 1 -b "$KERNEL_BRANCH" "$MODULES_REPO" modules
ln -s "$GITHUB_WORKSPACE/modules/vendor" src/vendor
ln -s "$GITHUB_WORKSPACE/modules/vendor" vnd/vendor
```

A guard step then fails the build if ANY symlink under `src/kernel` is still dangling,
so a layout regression is caught before the long compile instead of deep in kconfig.

Wrong turns that cost runs: putting `vendor/` at the kernel repo root
(`kernel/vendor`) left every link dangling; putting it at the workspace root
(`$WS/vendor`, kernel at `$WS/kernel`) resolved 88 links but left the single
`vnd/vendor` class (`drivers/base/kernelFwUpdate`) dangling. Only the nested
`src/kernel` layout resolves both.

## Toolchain

- Android clang `r383902b` from AOSP googlesource (android-11.0.0_r48), to match the
  stock kernel's clang 11.0.1 (read from the dumped boot Linux version string).
- `LLVM_IAS=0` (use the GNU assembler) plus GNU binutils cross toolchains, because
  clang 11 / 4.19 MTK code does not assemble cleanly with the integrated assembler.
- make args: `O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu-
  CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-
  LD=aarch64-linux-gnu-ld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy
  OBJDUMP=llvm-objdump STRIP=llvm-strip LLVM_IAS=0`.

## KernelSU-Next integration

- Installed with `curl .../KernelSU-Next/legacy/kernel/setup.sh | bash -s legacy` inside
  `src/kernel`, which symlinks `drivers/kernelsu` and wires the driver Kconfig/Makefile.
- **Use the `legacy` branch, not the default `dev`.** The repo has no `next` branch, so
  `bash -s next` silently fell back to `dev` (setup.sh does `git checkout <ref>` and on
  failure stays on the default branch). `dev` targets modern GKI (5.10+): it uses an
  LSM/tracepoint hook model (`lsm_hook`, `syscall_event_bridge`, `tp_marker`) and pulls
  in 5.8/5.9 APIs unguarded — `<linux/pgtable.h>`, `path_umount()`, and the renamed
  maccess helpers (`strncpy_from_user_nofault`, `copy_*_nofault`). On 4.19 that needs
  extensive hand-shimming. The `legacy` branch keeps the classic hook model and
  version-guards all of these (`<linux/pgtable.h>` only `>= 5.10`; `path_umount` has a
  `< 5.9` `sys_umount` fallback; `kernel_compat.c`/`patch_memory.c` define the maccess
  helpers for `< 5.8`). So `legacy` builds on 4.19 without patching KSU source.
- Hooks via **kprobes**: `CONFIG_KPROBES=y` is already in the stock defconfig and arm64
  selects HAVE_KPROBES/HAVE_KRETPROBES.
- **Pinned to the tag `v3.4.0-legacy`, not the `legacy` branch HEAD** (manager match).
  KSU-Next computes `KSU_VERSION = 30000 + git_commit_count + 289` in its Kbuild. The
  `legacy` branch HEAD has a higher commit count than the latest published manager
  (v3.4.2, build 33355), so the on-device manager reported "manager version too low"
  (kernel newer than any installable manager). `v3.4.0-legacy` is the newest legacy tag;
  its commit count is 3005 → `KSU_VERSION = 33294`, which is `<= 33355`, so manager
  v3.4.2 matches with no warning. (There is no `v3.4.1/2-legacy` tag; the legacy line
  tops out at v3.4.0-legacy.) `setup.sh` full-clones the repo so the commit count — and
  thus the version — is accurate; a shallow clone would wrongly report count 1.

## Errors encountered

| Symptom | Cause | Fix |
| --- | --- | --- |
| `can't open file "kernel/sched_assist/Kconfig"` at defconfig | vendor modules not overlaid; symlinks dangle | overlay modules repo `vendor/` (see nested layout) |
| still dangling after overlay at `kernel/vendor` | wrong level: targets resolve above kernel root | place `vendor/` as sibling/above, not inside `kernel/` |
| `drivers/base/kernelFwUpdate` dangling | second symlink class points at `../../../../vnd/vendor` | nest kernel at `src/kernel`, add `vnd/vendor` symlink |
| `oplus6765_21331.dts: 'oplus6765_21331/cust.dtsi' file not found` | per-project `cust.dtsi` are generated by Oppo's Android build; absent standalone. These dtbs are DTB **overlays** (`CONFIG_BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES`), not the appended boot dtb | disable the overlay build in the config fragment; `Image.gz-dtb` only needs the base `mediatek/mt6765` appended dtb, and AnyKernel3 flashes only `boot` (dtbo partition stays stock) |
| `sucompat.c: 'linux/pgtable.h' file not found` | `bash -s next` installed the GKI-only `dev` branch (no `next` branch exists); dev includes 5.8+ headers unguarded | switch KSU-Next ref to `legacy` (classic hook model, version-guards old kernels) |
| `implicit declaration of 'strncpy_from_user_nofault'` (-Werror) | same: `dev` uses the 5.8 maccess rename; on 4.19 it is `strncpy_from_unsafe_user` | same fix — `legacy` defines it for `< 5.8` in `kernel_compat.c` |
| `'../../../../../kernel-4.19/drivers/power/supply/charger_class.h' file not found` (oplus charger driver) | Oppo vendor code hardcodes relative includes into a kernel dir named `kernel-4.19` (the stock build root). The quoted include resolves physically through the `drivers/power/oplus` symlink and climbs into `modules/vendor` | alias `kernel-4.19 -> src/kernel` at `$GITHUB_WORKSPACE`, `modules/`, and `modules/vendor/` (the levels the physical climb lands on). A self-link inside `src/kernel` does NOT work — `open()` resolves `..` after symlink expansion, not lexically |

## DTB note (why dropping the overlays is safe here)

`k65v1_64_bsp_defconfig` sets:
- `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES="mediatek/mt6765"` — the base SoC dtb
  appended to the kernel to form `Image.gz-dtb`. This one builds fine.
- `CONFIG_BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES="mediatek/oplus6765_21331 ..."` — the
  per-project overlays (dtbo) that need the missing generated `cust.dtsi`.

We flash only `boot` via AnyKernel3 (`block=boot`), so the stock `dtbo` partition is
untouched and the overlays are not needed. The config fragment disables the overlay
build. (Our device is CPH2387, project ~21334 / board dts oplus6765_21333; not needed
for a pure boot-kernel build.)

## SUSFS status

Deferred until the KSU-only build is green. SUSFS on non-GKI 4.19 is best-effort; the
`50_add_susfs_in_kernel-4.19.patch` is expected to have failed hunks against this exact
tree that need manual `.rej` fixups. That is a separate task; the `.rej` list will be
recorded here once the KSU-only build is green and SUSFS is attempted.
