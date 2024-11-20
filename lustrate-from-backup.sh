#!/bin/bash

# Automatic lustrate script for Oracle OCI Ubuntu machines
# Usage:
# ./lustrate-from-backup.sh <hostname>
#
# This assumes the following:
#
# - Nix is already installed, in single-user mode
#   curl -L https://nixos.org/nix/install | sh
#   (restart shell after running)
#
# - nixos config is present at ~/nixos-infra (and is a flake)

set -e

cd ~/nixos-infra

echo "[MEOW] setting up nix channels"
nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs
nix-channel --update

echo "[MEOW] install nixos-install-tools"
nix-env -f '<nixpkgs>' -iA nixos-install-tools

echo "[MEOW] building system configuration \"$1\""
config_name=$1
nix build .#nixosConfigurations.${config_name}.config.system.build.toplevel --extra-experimental-features nix-command --extra-experimental-features flakes

echo "[MEOW] setting system profile to the newly built system"
link_path=$(readlink -f ./result)
echo "system = $link_path"
nix-env --profile /nix/var/nix/profiles/system --set "$link_path"

echo "[MEOW] creting /run/current-system symlink"
sudo ln -sfn /nix/var/nix/profiles/system /run/current-system

# nix is root nyow ------
echo "[MEOW] changing ownership of /nix"
sudo chown -R 0:0 /nix

echo "[MEOW] changing os gender marker and setting NIXOS_LUSTRATE"
sudo touch /etc/NIXOS
sudo touch /etc/NIXOS_LUSTRATE
echo etc/nixos | sudo tee -a /etc/NIXOS_LUSTRATE

# :3
echo "[MEOW] nuking /boot :3"
echo "(i assume you already have a backup dork)"
sudo rm -rf /boot

# needs to be ran twice for some reason to install the boot entries properly
echo "[MEOW] switching to configuration"
sudo NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot

echo "==================="
echo "MEOW! lustration complete!"
echo "now, make sure the boot entries are set up correctly and reboot!"
