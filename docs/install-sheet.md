# NECD OS install sheet (for IT)

> **Draft.** Written before the first install from the ISO. Steps marked ⚠ are unverified; correct them after the first real install.

**What this does:** erases one PC's disk and installs NECD OS from a USB drive. Staff data on that disk is **lost**. Allow about 30 minutes. The PC needs a wired network connection during install (the installer downloads the latest signed image).

## You need
- A USB drive of 16 GB or more (it will be erased).
- The NECD OS installer ISO from the admin: `necd-os-installer.iso` ⚠ (download location to be set).
- The target PC: UEFI, 4 GB RAM or more, 40 GB disk or more. Secure Boot can stay on ⚠.

## 1. Write the ISO to the USB drive
**From Windows**
1. Download **Rufus** (rufus.ie) and run it.
2. Choose the USB drive under *Device*, click **SELECT** and pick the ISO.
3. Click **START**. If asked, choose **Write in DD Image mode**, then confirm the erase.

**From Linux**
- **Easiest:** open **Fedora Media Writer** or **GNOME Disks → Restore Disk Image**, pick the ISO and the USB drive.
- **Command line** (replace `sdX` with the USB device from `lsblk`; the wrong device destroys that disk):
  ```
  sudo dd if=necd-os-installer.iso of=/dev/sdX bs=4M status=progress conv=fsync
  ```

## 2. Install
1. Plug the USB drive into the PC, power on and open the boot menu (usually **F12**, **F10**, **Esc** or **F9**). Pick the USB drive (UEFI entry).
2. In the installer: choose language and time zone, pick the target disk (the whole disk), and **create the administrator account** with a strong password. Record it in the clinic's password manager.
3. Click **Install**, wait, then remove the USB drive and **Reboot**. The first boot finishes the setup and may take a few minutes. Keep it on the network.

## 3. First boot
1. Log in. Open **Konsole** (Terminal) and name the PC for its room:
   ```
   sudo hostnamectl set-hostname necd-<room>      # e.g. necd-front-desk
   hostnamectl                                     # check "Static hostname"
   ```
2. Confirm it is on the signed stable image:
   ```
   bootc status
   ```
   It should show `ghcr.io/northeast-childrens-dentistry/necdos:stable`.
3. Check the network and open Chrome. Then create each staff user (**System Settings → Users**).

## After install
- **Updates are automatic.** They are downloaded during the day and applied by a reboot at 02:00 only when nobody is logged in. Nothing to do.
- **If an update breaks something:** `sudo bootc rollback`, then reboot. Staff do not roll back; they call IT.
- **Don't** `dnf install` or edit `/usr`. Changes vanish on the next update. Ask the admin to add apps to the image.
- **Factory reset** of user data: `ujust powerwash` (admin only).

## If it doesn't go well
- **Won't boot from the USB drive:** try another USB port, re-write the drive, or turn Secure Boot off in firmware and tell the admin ⚠.
- **Installer can't download the image:** check the cable and that `ghcr.io` is reachable.
- Otherwise note the screen and error, and contact the admin.
