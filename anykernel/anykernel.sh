# AnyKernel3 config — Oppo A57 4G (CPH2387 / OP5355, MT6765), monolithic boot (hdr v2)
properties() { '
kernel.string=Oppo A57 MT6765 KernelSU-Next + SUSFS
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=1
device.name1=CPH2387
device.name2=OP5355
device.name3=CPH2387EEA
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
'; }

block=boot
is_slot_device=1
ramdisk_compression=auto
patch_vbmeta_flag=auto

. tools/ak3-core.sh

split_boot
flash_boot
