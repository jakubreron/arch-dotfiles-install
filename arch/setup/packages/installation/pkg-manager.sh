#!/bin/sh

get_fastest_mirrors() {
  if ! command -v reflector >/dev/null 2>&1; then
    log_pretty_message "Installing reflector"
  fi

  log_pretty_message "Getting the fastest mirrors before installing the dotfiles packages"
  sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist
}

install_pkglists() {
  if command -v "$di_pkg_manager_helper" >/dev/null 2>&1; then
    log_pretty_message "Installing dotfiles packages"
    install_pkg - < "$pkglists_dir/$di_pkg_type/pacman.txt";
  fi
}

get_fastest_mirrors
install_pkglists