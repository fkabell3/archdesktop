# archdesktop

Arch Linux installation script with many suckless.org utilities. This setup tries to utilize simple tools and scripts in lieu of more complicated alternatives. For instance,<br>

* RSS/YouTube subscriptions are handled with sfeedrc
* Password management is dealt with files, directories, and xclip
* Quick screenshotting, and network/sound configuration
* Terminal emulation has the ability to open files and links easily
* doas instead of sudo, /bin/sh -> dash
* Virtual machines can be spawned trivally with a few keystrokes

All of the above actions utilize dmenu for a consistent UI. Lack of mouse use is a goal, but mouse support has been patched in. A transparency theme as been applied to get that nice look often seen in Apple software.<br>

Many of the companion scripts will not work alone; they must either be used on a system setup with archinstall.sh, or edited manually to become usable on your system. The most notable offenders are:

* Heavy usage of `$DMENULINENUM` and `$BROWSER` which are both exported from xinitrc. Make sure you set those variables if you are using the scripts on yout own system without `archinstall.sh`. Do note that this version of dmenu has a small patch applied to hide empty lines, it may not make sense to use `$DMENULINENUM` if your build of dmenu does not have that.
* dmenu_rss contains a binary called sfeed_plain_trimmed. This is a version of sfeed with lines commented out and `printutf8pad()` replaced with a `printf()` statement. The resultant binary is much easier to parse with awk, as it is done in dmenu_rss.<br>

This project is far from complete. I have been running it off of a USB for some time so there is probably a lot of breakage migrating to a proper version control system such as git.<br>

Feedback is appreciated.
