#!/bin/sh
# TODO: setup infinite timeout for sudo
# TODO: setup grub options:
# ```sh
#   echo '
#     GRUB_FORCE_HIDDEN_MENU="true"
#     GRUB_HIDDEN_TIMEOUT="0"
#   ' | sudo tee -a /etc/default/grub
# ```
# sudo grub-mkconfig -o /boot/grub/grub.cfg

prepare_user() {
  sudo usermod -a -G wheel "$user" && mkdir -p "$home" && sudo chown "$user":wheel /home/"$user"
}

update_system() {
  remove_db_lock
  sudo pacman --noconfirm -Syu
}

setup_core_packages() {
  for package in curl ca-certificates base-devel git ntp zsh rust laptop-detect stow reflector rsync; do
    install_pkg "$package"
  done
}

setup_core_settings() {
  # Make pacman colorful, concurrent downloads and Pacman eye-candy.
  grep -q "ILoveCandy" /etc/pacman.conf || sudo sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
  sudo sed -Ei "s/^#(ParallelDownloads).*/\1 = 15/;/^#Color$/s/#//" /etc/pacman.conf

  # Use all cores for compilation.
  sudo sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

  # Allow wheel users to sudo with password and allow several system commands
  # (like `shutdown` to run without password).
  echo "%wheel ALL=(ALL:ALL) ALL" | sudo tee /etc/sudoers.d/00-wheel-can-sudo
  echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -u -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" | sudo tee /etc/sudoers.d/01-cmds-without-password
  echo "Defaults editor=/usr/bin/nvim" | sudo tee /etc/sudoers.d/02-visudo-editor
  echo "Defaults timestamp_timeout=1440" | sudo tee /etc/sudoers.d/03-sudo-timeout
  sudo mkdir -p /etc/sysctl.d
  echo "kernel.dmesg_restrict = 0" | sudo tee /etc/sysctl.d/dmesg.conf

  echo "export \$(dbus-launch)" | sudo tee /etc/profile.d/dbus.sh
}

setup_touchpad() {
  if laptop-detect -s > /dev/null; then
    [ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	Option "Tapping" "on"
  Option "NaturalScrolling" "true"
EndSection' | sudo tee /etc/X11/xorg.conf.d/40-libinput.conf
  fi
}

create_dirs() {
  mkdir $home/{Documents,Downloads,Music,Pictures,Videos,Cloud,Storage}
  mkdir -p $home/.local/{bin,share,src}
  mkdir -p $home/.local/bin/{cron,dmenu,git,layouts,qemu,statusbar,sync,video,volume}

  mkdir -p "$dotfiles_dir"
}

clone_dotfiles_repos() {
  git clone "$voidrice_repo" "$voidrice_dir"
  git clone "$pkglists_repo" "$pkglists_dir"

  git --git-dir "$voidrice_dir" pull
  git --git-dir "$pkglists_dir" pull

  git --git-dir "$voidrice_dir" submodule update --init --remote --recursive
}

replace_stow() {
  stow --adopt --target="$home" --dir="$dotfiles_dir" voidrice
}

setup_basics() {
  prepare_user
  update_system
  setup_core_packages
  setup_core_settings
  setup_touchpad
  create_dirs
  clone_dotfiles_repos
  replace_stow
}