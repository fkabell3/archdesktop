# archdesktop

Arch Linux installation script with many suckless.org utilities. This setup tries to utilize simple tools and scripts in lieu of more complicated alternatives. For instance,<br>

* RSS/YouTube subscriptions are handled with sfeedrc
* Password management is dealt with files, directories, and xclip
* Easy screenshotting
* Terminal emulation has the ability to open files and links easily
* Virtual machines can be spawned trivally with a few keystrokes

All of the above actions utilize dmenu for a consistent UI. Lack of mouse use is a goal, but mouse support has been patched in. A transparency theme as been applied to get that nice look often seen in Apple software.<br>

Many of the companion scripts will not work alone; they must either be used on a system setup with archinstall.sh, or edited manually to become usable on your system. The most notable offenders are:

* Heavy usage of `dmenu -l $DMENULINENUM', where $DMENULINENUM is exported from xinitrc. On your system this may be horrible UI if you do not have the same patches as the dmenu in this repo does, since this dmenu has been already preconfigured to hide all empty lines.
* dmenu_rss contains a binary called sfeed_plain_trimmed. This is a version of sfeed with lines commented out and printutf8pad() replaced with a printf() statement. The resultant binary is much easier to parse with awk, as it is done in dmenu_rss.<br>

This project is far from complete. I have been running it off of a USB for some time so there is probably a lot of breakage migrating to a proper version control system such as git. Also I need to make guibuild.sh a diff file instead of a script which abuses sed. For the time being I will just have precompiled (amd64) binaries in the repo.<br>

Feedback is appreciated.
