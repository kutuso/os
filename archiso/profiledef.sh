#!/usr/bin/env bash
# shellcheck disable=SC2034

# kutu OS Build Profile Definition

iso_name="kutu-os"
iso_label="KUTU_OS_$(date +%Y%m)"
iso_publisher="kutu.so <https://kutu.so>"
iso_application="kutu OS - ML Inference Optimized Linux"
iso_version="$(date +%Y.%m.%d)"
install_dir="kutu"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.grub.esp' 'uefi-x64.systemd-boot.esp'
           'uefi-ia32.grub.eltorito' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/usr/local/bin/kutu-setup"]="0:0:755"
  ["/usr/local/bin/kutu-optimize"]="0:0:755"
  ["/etc/sudoers.d"]="0:0:750"
)
