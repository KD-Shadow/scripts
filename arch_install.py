from archinstall import *

# Hardcoded user config
user_name = "sh4dow"

# Ask for root and user password only
root_password = input("Enter root password: ")
user_password = input(f"Enter password for {user_name}: ")

# Start profile configuration
with Installer("/dev/sda", filesystem_type="btrfs") as installation:
    # Set mirrors and base packages (India)
    installation.set_mirrors("IN")  # Mirror region set to India
    installation.install_base_system()

    # Set locale (example: en_US.UTF-8)
    installation.set_locale("en_US.UTF-8")
    
    # Set time zone (example: Asia/Kolkata)
    installation.set_timezone("Asia/Kolkata")

    # Disk encryption with LUKS
    installation.disk_format("/dev/sda", encryption=True, encryption_passphrase=root_password)
    installation.luks_open("/dev/sda", "cryptroot")
    
    # Create a Btrfs filesystem on the encrypted volume
    installation.create_filesystem("/dev/mapper/cryptroot", "btrfs")

    # Mount the encrypted disk
    installation.mount("/dev/mapper/cryptroot", "/mnt")
    
    # Install GRUB bootloader for encrypted system
    installation.install_bootloader("grub")
    
    # Set GRUB to support LUKS encryption
    installation.add_additional_packages(["os-prober"])
    installation.update_grub()

    # Add user
    installation.user_add(user_name, password=user_password, sudo=True)

    # Set root password
    installation.set_root_password(root_password)

    # Install necessary packages
    installation.add_additional_packages([
        "networkmanager",
        "intel-ucode",
        "xf86-video-intel",
        "btrfs-progs",
        "pipewire",
        "pipewire-alsa",
        "pipewire-pulse",
        "pipewire-jack",
        "wireplumber"
    ])

    # Enable services
    installation.enable_service("NetworkManager")
    installation.enable_service("pipewire")
    installation.enable_service("pipewire-pulse")

    # Configure fstab
    installation.generate_fstab()

    print("Installation complete.")

