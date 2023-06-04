# shscripts

This repo contains my desktop enviroment which makes heavy usage of suckless.org utilities such as dmenu(1) and dwm(1).
Some of the scripts expect custom variables to be exported, such as $DMENULINENUM and $BROWSER.
Some of the scripts expect certain patches to be applied. For example, dmenu's -l argument is always followed by $DMENULINENUM, since a patch is applied which hides vacant lines.
dmenu_rss depends on sfeed_plain_trimmed, which is just sfeed_plain but with some lines commented out and a printutf8pad() swapped with a printf().
To get these custom build binaries, either use my Arch Linux installation script (archinstall.sh) or build them yourself with guibuild.sh. (I know that script should be a .diff file but I'm new to this lol.)
Set variables in a place where they will get exported before GUI starts, ~/.xinit is a good place, I use /etc/X11/xinit/xinitrc on Arch (which is not the same for, say Alpine).
Feedback is appreciated.
