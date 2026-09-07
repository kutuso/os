# Installing kutu OS

kutu OS boots as a live USB you can explore before committing anything to
disk. When you like what you see, the installer puts it on your machine
offline, in a few clicks. No accounts, no telemetry, no network required.

## What you need

| Requirement | Detail |
|---|---|
| CPU | x86_64 (any modern Intel/AMD) |
| RAM | 2 GB minimum for the live session; 4 GB+ recommended |
| Disk | 8 GB+ for the installed system |
| Media | A USB stick (2 GB+) or DVD |
| Firmware | BIOS or UEFI; **Secure Boot must be off** (not yet supported) |

## 1. Download and verify

Grab the latest ISO from the
[releases page](https://github.com/kutuso/os/releases) and check it against
the published `SHA256SUMS`:

```sh
sha256sum -c --ignore-missing SHA256SUMS
```

The ISO is kept under 2 GiB and boots on both BIOS and UEFI machines.

## 2. Write the USB stick

On Linux:

```sh
sudo dd if=kutu-os-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/dev/sdX` with your USB device (**the whole device, not a
partition** — and everything on it will be destroyed). Ventoy and Etcher
work too.

## 3. Boot the live session

- Pick the USB in your firmware boot menu (often F12/F10/Esc).
- The session logs in automatically as the `kutu` user — poke around.
- Everything runs from RAM; your disk is untouched until you install.
- The boot menu also offers a memory test (`memtest86+`) if you suspect
  your RAM.

If the desktop fails to start on exotic graphics hardware, try the
"safe" boot entry from the boot menu.

## 4. Run the installer

Double-click **Install kutu OS** on the desktop.

- **Partitioning** — nothing destructive is preselected. Choose:
  - *Erase disk* — the whole disk becomes kutu OS (simplest),
  - *Manual partitioning* — alongside another OS, custom layouts,
    LUKS2 encryption, btrfs/ext4, whatever you need.
- **Swap** — the default creates a hibernation-capable swap partition
  (about RAM-sized). On small SSDs pick a smaller choice; zswap makes
  even modest swap go far.
- **User** — pick a username and a password (8+ characters). Autologin
  is off by default on installed systems; the live session's autologin
  never carries over.
- Click through the summary and let it finish, then reboot and remove
  the USB.

The installer works fully offline — it copies the running system to disk
and rebuilds the boot chain locally.

## 5. First boot on your machine

Within seconds of first boot, kutu OS calibrates itself to your RAM:

| Your RAM | Mode | Effect |
|---|---|---|
| under 6 GB | saver | tighter per-app and session ceilings |
| 6–16 GB | balanced | the documented defaults |
| over 16 GB | performance | looser ceilings |

Log in with the password you set. Verify the stack is healthy with:

```sh
kutu-check-kernel
```

All lines should read `PASS` (also reported in the journal after every
kernel update).

## Keeping it current

Installed systems update like any Arch machine:

```sh
sudo pacman -Syu
```

kutu's own packages flow from the kutu repository over HTTPS — including
memory-stack fixes and tuning improvements. The wiki, the AUR and every
other Arch convention keep working.

## Just the packages, no reinstall

Already on Arch? Add the kutu repo to `/etc/pacman.conf`:

```ini
[kutu]
Server = https://kutuso.github.io/os/repo/$arch/
```

Then `sudo pacman -Sy kutu-memory` for the kernel-level stack, or
`kutu-desktop-xfce` for the curated desktop on top.

## If something goes wrong

- **Installed system won't boot** — boot the live USB and inspect the
  disk; file an issue with the Calamares log from
  `/var/log/calamares/` on the live system.
- **"My app got killed"** — systemd-oomd reclaimed a memory hog;
  check `systemctl status 'app-*.scope'` and
  `journalctl -b -u systemd-oomd`.
- **Suspect the tuning** — `sudo kutu-reset` returns the memory stack to
  stock Arch behavior. Reboot, compare, and please report what you find.
