#!/usr/bin/env bash
# Runs inside the airootfs chroot at ISO build time (deprecated but supported
# archiso hook). If archiso drops support, migrate to a boot-time oneshot
# conditioned on /run/archiso/bootmnt.
set -euo pipefail

useradd -m -G wheel -s /bin/bash kutu
passwd -d kutu

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

systemctl set-default graphical.target
systemctl enable NetworkManager.service sshd.service
# kutu-* units, lightdm and oomd are enabled by their packages' install scriptlets
