#!/bin/bash
set -e

# === User Input ===
read -rp "Enter target drive (e.g., /dev/sda): " drive
read -rp "Enter hostname: " hostname
read -rsp "Enter root password: " rootpass; echo
read -rp "Enter locale (e.g., en_US.UTF-8): " locale
read -rp "Enter timezone (e.g., Europe/London): " timezone
read -rp "Enter new username: " username
read -rsp "Enter password for $username: " userpass; echo

# === Partitioning ===
echo "Partitioning $drive..."
parted --script "$drive" \
  mklabel gpt \
  mkpart primary fat32 1MiB 512MiB \
  set 1 esp on \
  mkpart primary btrfs 512MiB 100%

mkfs.fat -F32 "${drive}1"
mkfs.btrfs -f "${drive}2"

# === Btrfs Subvolumes ===
mount "${drive}2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
umount /mnt

mount -o noatime,compress=zstd,space_cache=v2,subvol=@ "${drive}2" /mnt
mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg}
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home "${drive}2" /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,subvol=@log "${drive}2" /mnt/var/log
mount -o noatime,compress=zstd,space_cache=v2,subvol=@pkg "${drive}2" /mnt/var/cache/pacman/pkg
mount "${drive}1" /mnt/boot

# === Package Installation ===
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware intel-ucode btrfs-progs \
  grub efibootmgr sudo networkmanager \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  mesa xf86-video-intel

# === fstab ===
genfstab -U /mnt >> /mnt/etc/fstab

# === Chroot Configuration ===
arch-chroot /mnt /bin/bash <<EOF
echo "$hostname" > /etc/hostname

# Locale
echo "$locale UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$locale" > /etc/locale.conf

# Timezone
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

# Root Password
echo "root:$rootpass" | chpasswd

# User Setup
useradd -m -G wheel "$username"
echo "$username:$userpass" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Enable services
systemctl enable NetworkManager
systemctl enable pipewire

# Bootloader
sed -i 's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="initrd=\/intel-ucode.img /' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "✅ Arch installed! You can reboot into your system now."

