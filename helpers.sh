#!/bin/sh

install_pkg() {
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}
