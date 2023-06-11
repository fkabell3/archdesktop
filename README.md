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
* Transparent priviledge dropping when running `makepkg` or `yay` as root

Installation Instructions:
* Connect to network<br>
Ethernet should usually work out the box. This network-heavy script downloads the whole operating system and GUI off the internet so it may be worth your time to use a wired connection. If you want to use WiFi, try<br>
`iwctl station <iface> connect '<SSID>'`
* Download git<br>
`pacman --noconfirm -Sy git`<br>
If that fails, try:<br>
`pkill gpg-agent; rm -rf /etc/pacman.d/gnupg/* && pacman-key --init && pacman-key --populate && pacman --noconfirm -Sy git`
* `export gitdir="$PWD"/archdesktop`
* `git -C "$(dirname "$gitdir")" clone --depth 1 https://github.com/fkabell3/archdesktop`
* `"$gitdir"/archinstall.sh nochroot`<br>
Note: you can also edit variables directly inside the script.
* When the first part of the script is done, hit enter to chroot and call it again with $1 as chroot<br>
`/archinstall.sh chroot`
* When script is done, exit and reboot into the GUI.

Your feedback is appreciated.
