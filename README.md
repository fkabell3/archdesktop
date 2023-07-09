# archdesktop

Arch Linux installation script with many suckless.org utilities. This setup tries to make use of simple tools and scripts in lieu of more complicated alternatives. For instance,<br>

* Password management is dealt with files, directories, and xclip.
* YouTube subscriptions are handled with sfeedrc.
* Quick screenshotting, and network/sound/brightness configuration.
* Terminal emulation has the ability to open files and links easily.
* Spawn virtual machines trivally with a few keystrokes.

All of the above actions utilize `dmenu` for a consistent UI on Xorg. Lack of mouse use is a goal, but mouse support has been patched in. A transparency theme has been applied to get that nice look often seen in Apple software, but without the proprietary garbage. HiDPI is supported.<br>

<img width="1000" src="https://github.com/fkabell3/archdesktop/blob/main/archdesktop.png">

Non-GUI features include:<br>
* Mostly transparent priviledge dropping when running `makepkg` or `yay` as root.
* `doas` instead of `sudo` (with shim installed), `/bin/sh -> dash`.
* Force a good choice of DNS nameservers (1.1.1.1/9.9.9.9); ignore DHCP DNS.
* If using EFI, installs an EFI shell to the root of the ESP.
* Limine bootloader or EFI boot stub with bootsplash image.
* `dracut` instead of `mkinitcpio` (seems to work fine but probably needs more testing).

Install features:<br>
* Straightforward installation questions, also easily configurable by editing variables at begining of script
* Edit partition/swap with vim. The script automates the rest. Only EXT4 fs is supported.
* BIOS/EFI are both supported. EFI has a choice between PMBR/GPT. GPT has a choice between bootloader and EFI boot stub.
* Script can (and does in the 2nd half) run with `dash`.
* Script is capable of chrooting itself.
* If user data is valid, then script is `set -e` compliant. The script may exit on any failures which result from bad user input.

Installation Instructions:
* [Download](https://archlinux.org/download/), burn, and boot into an Arch Linux installation enviroment.
* Connect to network.<br>
Either plug in an Ethernet cable or for WiFi try:<br>
`iwctl -P '<PSK>' station <iface> connect '<SSID>'`
* `curl https://raw.githubusercontent.com/fkabell3/archdesktop/main/archinstall.sh > archinstall.sh`<br>
You can not pipe | curl directly into sh. You must save it as a file and then run it.
* `vim archinstall.sh`<br>
(Optional) Edit variables directly inside the script to avoid interactive querying.
* `sh archinstall.sh`
* When script is done, exit and reboot into the GUI.<br>
**If script fails for any reason, reboot before trying again.**<br>
If using EFI, read TROUBLESHOOTING.md to get bootloader/EFI stub working in the case that efibootmgr(8) fails due to poor EFI implementations. If your reboot fails, then this is probably the best first troubleshooting step.<br>

Optional Postinstallation Instructions:<br>
(Spawn terminals with Super/Enter, spawn application launcher with Super/P. Read dwm(1).)
* Place a background in /usr/local/share/backgrounds/.<br>
If there is only one background, it is chosen by default. If there is more than one, edit /etc/X11/xdm/Xsetup_0 to specify which one you want.<br>
* Populate /var/vm/ with subdirectories which contain a file called disk (`dd if=/dev/zero of=/var/vm/<name>/disk`) and an .iso file. Then start a virtual machine.<br>
* Enable the installed LibreWolf (Firefox fork) browser addons by starting a browser and clicking the handburger menu on the top right.<br>
* Place passwords in `$HOME/.passwords`

Please inform me if the scipt fails on your system (after TROUBLESHOOTING.md).<br>
Your feedback is appreciated. 
