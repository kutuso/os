#!/usr/bin/env bash
# Runs inside the airootfs chroot at ISO build time (deprecated but supported
# archiso hook). If archiso drops support, migrate to a boot-time oneshot
# conditioned on /run/archiso/bootmnt.
set -euo pipefail

useradd -m -G wheel -s /bin/bash kutu
passwd -d kutu
# Arch's lightdm PAM requires autologin group membership for autologin
groupadd -r autologin 2>/dev/null || true
usermod -aG autologin kutu
# Installer shortcut on the live desktop
install -d -m 755 /home/kutu/Desktop
install -m 755 /usr/share/applications/calamares.desktop /home/kutu/Desktop/install-kutu-os.desktop
chown -R kutu:kutu /home/kutu/Desktop

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

systemctl set-default graphical.target
systemctl disable systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service \
  systemd-networkd-varlink.socket systemd-networkd-varlink-metrics.socket systemd-networkd-resolve-hook.socket \
  systemd-resolved.service systemd-resolved-monitor.socket systemd-resolved-varlink.socket \
  systemd-homed.service systemd-homed-activate.service 2>/dev/null || true
systemctl mask systemd-rfkill.service systemd-rfkill.socket
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
systemctl enable NetworkManager.service sshd.service systemd-timesyncd.service \
  fstrim.timer bluetooth.service cups.socket ufw.service tlp.service thermald.service
# kutu-* units, lightdm and oomd are enabled by their packages' install scriptlets
