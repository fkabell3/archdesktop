# archdesktop

Arch Linux installation script with many suckless.org utilities. This setup tries to utilize simple tools and scripts in lieu of more complicated alternatives. For instance,<br>

* RSS/YouTube subscriptions are handled with sfeedrc
* Password management is dealt with files, directories, and xclip
* Quick screenshotting, and network/sound configuration
* Terminal emulation has the ability to open files and links easily
* Virtual machines can be spawned trivally with a few keystrokes

All of the above actions utilize dmenu for a consistent UI. Lack of mouse use is a goal, but mouse support has been patched in. A transparency theme has been applied to get that nice look often seen in Apple software.<br>

<img width="1000" src="https://github.com/fkabell3/archdesktop/blob/main/archdesktop.png">

Non-GUI features include:<br>
* doas instead of sudo (with shim installed), `/bin/sh -> dash`
* Transparent privlidge dropping when running `makepkg` or `yay` as root

Installation Instructions:
* Connect to network
    Ethernet should usually work out the box. The script downloads the whole operating system and GUI off the internet so it may be worth your time using a wired connection. If you want to use WiFi, try
    `iwctl station <iface> connect '<SSID>'`
* Download git
    `pacman --noconfirm -Sy git`
    If that fails, try:
	`pkill gpg-agent; rm -rf /etc/pacman.d/gnupg/* && pacman-key --init && pacman-key --populate && pacman --noconfirm -Sy git`
* `export gitdir="$PWD"/archdesktop`
* `git -C "$(dirname "$gitdir")" clone --depth 1 https://github.com/fkabell3/archdesktop`
* `"$gitdir"/archinstall.sh`
Note: you can also edit variables directly inside the script.

Your feedback is appreciated.
