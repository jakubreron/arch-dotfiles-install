#!/bin/sh
# TODO: provide options for "primary, secondary, work" pkgtypes
# TODO: base more things on this: https://github.com/linuxmobile/hyprland-dots

dotfiles_dir="$HOME/.config/personal/testing"
dotfiles_repo="https://github.com/jakubreron/voidrice.git"

pkglists_repo="https://github.com/jakubreron/pkglists.git"
pkgtype="secondary"

export TERM=ansi

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

install_pkg() {
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

refresh_keys() {
	case "$(readlink -f /sbin/init)" in
	*systemd*)
		whiptail --infobox "Refreshing Arch Keyring..." 7 40
		pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
		;;
	*)
		whiptail --infobox "Enabling Arch Repositories for more a more extensive software collection..." 7 40
		if ! grep -q "^\[universe\]" /etc/pacman.conf; then
			echo "[universe]
Server = https://universe.artixlinux.org/\$arch
Server = https://mirror1.artixlinux.org/universe/\$arch
Server = https://mirror.pascalpuffke.de/artix-universe/\$arch
Server = https://artixlinux.qontinuum.space/artixlinux/universe/os/\$arch
Server = https://mirror1.cl.netactuate.com/artix/universe/\$arch
Server = https://ftp.crifo.org/artix-universe/" >>/etc/pacman.conf
			pacman -Sy --noconfirm >/dev/null 2>&1
		fi
		pacman --noconfirm --needed -S \
			artix-keyring artix-archlinux-support >/dev/null 2>&1
		for repo in extra community; do
			grep -q "^\[$repo\]" /etc/pacman.conf ||
				echo "[$repo]
Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf
		done
		pacman -Sy >/dev/null 2>&1
		pacman-key --populate archlinux >/dev/null 2>&1
		;;
	esac
}

create_dirs() {
  mkdir "$HOME"/{Documents,Downloads,Music,Pictures,Videos,Cloud,Storage}
  mkdir -p "$HOME"/.local/{bin,share,src}
  mkdir -p "$dotfiles_dir"
}

clone_dotfiles_repos() {
  git clone "$dotfiles_repo" "$dotfiles_dir" || return 1
  git clone "$pkglists_repo" "$dotfiles_dir" || return 1
}

install_pkglists() {
  paru --noconfirm --needed -S - < "$dotfiles_dir/pkglists/$pkgtype/pacman.txt";
}

replace_stow() {
  stow --adopt --target="$HOME" --dir="$dotfiles_dir" voidrice
}

enable_cache_management() {
  sudo journalctl --vacuum-time=4weeks 

  echo '[Unit]
  Description=Clean-up old pacman pkg

  [Timer]
  OnCalendar=monthly
  Persistent=true

  [Install]
  WantedBy=multi-user.target' | sudo tee -a /etc/systemd/system/paccache.timer

  echo '[Trigger]
  Operation = Upgrade
  Operation = Install
  Operation = Remove
  Type = Package
  Target = *

  [Action]
  Description = Cleaning pacman cache with paccache …
  When = PostTransaction
  Exec = /usr/bin/paccache -r' | sudo tee -a /usr/share/libalpm/hooks/paccache.hook
}

# TODO: only on laptops
# TODO: install https://github.com/AdnanHodzic/auto-cpufreq#auto-cpufreq-installer
# TODO: and setup into /etc/auto-cpufreq.conf https://github.com/AdnanHodzic/auto-cpufreq#auto-cpufreq-modes-and-options (min freq on battery and so on)
# TODO: also this: https://github.com/intel/dptf or use "thermald"
# install_auto_cpufreq() {
#   git clone https://github.com/AdnanHodzic/auto-cpufreq.git
#   cd auto-cpufreq && sudo ./auto-cpufreq-installer
#   sudo auto-cpufreq --install
# }

install_zap() {
  zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh)
}

install_keyd() {
  path="$HOME/Downloads/keyd"
  git clone https://github.com/rvaiya/keyd "$path" || return 1
  cd "$path" || return 1
  make && sudo make install
  sudo systemctl enable keyd && sudo systemctl start keyd
  rm -rf "$path"
  global_config_path="/etc/keyd/defaulf.conf"
  echo "[ids]

*

[main]

capslock = overload(meta, esc)

# Remaps the escape key to capslock
esc = capslock" | sudo tee "$global_config_path"
}

setup_basics() {
  timedatectl set-ntp on # network time sync
}

setup_bluetooth() {
  sudo sed -i 's/^#AutoEnable=true/AutoEnable=true/g' /etc/bluetooth/main.conf
  sudo systemctl enable bluetooth.service --now
}

setup_program_settings() {
  touch $HOME/.config/mpd/{database,mpdstate} || return 1

  gsettings set org.gnome.nautilus.preferences show-hidden-files true
}

setup_cloud() {
  systemctl --user enable grive@$(systemd-escape Cloud).service
  systemctl --user start grive@$(systemd-escape Cloud).service
}

### THE ACTUAL SCRIPT ###

setup_basics() {
  pacman --noconfirm --needed -Sy libnewt ||
    error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"

  for x in curl ca-certificates base-devel git ntp zsh; do
    whiptail --title "Setting up the basics" \
      --infobox "Installing \`$x\` which is required to install and configure other programs." 8 70
    install_pkg "$x"
  done

  refresh_keys ||
    error "Error automatically refreshing Arch keyring. Consider doing so manually."

  [ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # copy just in case

  # Allow user to run sudo without password. Since AUR programs must be installed
  # in a fakeroot environment, this is required for all builds with AUR.
  trap 'rm -f /etc/sudoers.d/larbs-temp' HUP INT QUIT TERM PWR EXIT
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/larbs-temp

  # Make pacman colorful, concurrent downloads and Pacman eye-candy.
  grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
  sed -Ei "s/^#(ParallelDownloads).*/\1 = 15/;/^#Color$/s/#//" /etc/pacman.conf

  # Use all cores for compilation.
  sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

  # Allow wheel users to sudo with password and allow several system commands
  # (like `shutdown` to run without password).
  echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-larbs-wheel-can-sudo
  echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -u -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-larbs-cmds-without-password
  echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-larbs-visudo-editor
  mkdir -p /etc/sysctl.d
  echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf
}


# Basics
setup_basics
# install_manually paru || error "Failed to install AUR helper." # TODO: install AUR helper, create install_manually scirpt
create_dirs

# Start installing dotfiles after setting up the basics
clone_dotfiles_repos
install_pkglists
replace_stow
enable_cache_management

# Custom programs with their custom configurations (no AUR)
[ -x "$(command -v "zap")" ] || install_zap
[ -x "$(command -v "keyd")" ] || install_keyd

# Setup after installing everything
setup_basics
setup_bluetooth
setup_program_settings
setup_cloud
