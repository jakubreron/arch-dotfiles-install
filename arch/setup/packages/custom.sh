#!/bin/sh

# TODO: setup intel/dptf or thermald on laptop

install_auto_cpufreq() {
  if laptop-detect -s > /dev/null; then
    echo "Running on a laptop"
    path="$git_clone_path/auto-cpufreq"
    git clone https://github.com/AdnanHodzic/auto-cpufreq.git "$path"
    cd "$path" && sudo ./auto-cpufreq-installer
    sudo auto-cpufreq --install
    sudo systemctl enable --now auto-cpufreq.service
    sudo systemctl mask power-profiles-daemon.service
    curl -sL "https://raw.githubusercontent.com/AdnanHodzic/auto-cpufreq/master/auto-cpufreq.conf-example" | sudo tee /etc/auto-cpufreq.conf
    sudo sed -i '/^\[battery\]/,/^\[/s/^# scaling_min_freq = 800000/scaling_min_freq = 1600000/' /etc/auto-cpufreq.conf
    sudo systemctl restart auto-cpufreq.service
    rm -rf "$path"
  fi
}

install_keyd() {
  if ! command -v keyd &> /dev/null; then 
    path="$git_clone_path/keyd"
    git clone https://github.com/rvaiya/keyd "$path"
    cd "$path" || exit
    make && sudo make install
    sudo systemctl enable keyd && sudo systemctl start keyd
    cd ..
    rm -rf "$path"
    global_config_path="/etc/keyd/defaulf.conf"
    echo "[ids]
*

[main]
# leftcontrol = layer(emacs_control)
# rightcontrol = layer(emacs_control)
capslock = overload(meta, esc)
esc = capslock

leftalt = layer(mac_meta)
leftmeta = layer(mac_option)

# [emacs_control:C]
# b = left
# f = right 
# p = up
# n = down
# h = backspace
# a = home
# e = end
# m = enter
# w = C-backspace
# d = delete
# S-m = S-enter

[mac_option:A]

[mac_meta:C]
# Switch directly to an open tab (e.g. Firefox, VS code)
1 = A-1
2 = A-2
3 = A-3
4 = A-4
5 = A-5
6 = A-6
7 = A-7
8 = A-8
9 = A-9

# Copy
c = C-insert
# Paste
v = S-insert
# Cut
x = S-delete

# Move cursor to beginning of line
left = home
# Move cursor to end of Line
right = end" | sudo tee "$global_config_path"
  fi
}

install_auto_cpufreq
install_keyd
