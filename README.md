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
* doas instead of sudo (which shim installed), /bin/sh -> dash
* Transparent privlidge dropping when running `makepkg` or `yay` as root

Your feedback is appreciated.
