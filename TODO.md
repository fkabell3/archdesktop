# To Do/Bugs
Fixing current features is more important then adding new ones. Listed in order of priority:<br>

* Troubleshoot MBR (currently broken, or at least doesn't work in QEMU)
* Add MBR/GUID codes (search for $code, used with sfdisk)
* Change vm.sh overuse of `su -c' to runuser(1), and then take make vm's shell nologin for more priviledge seperation
* Split dmenu_launcher's System catagory into Display and System. Display will have screenshotting, brightness control, and screen lock.
* Give partitioning warning when /usr/bin is on it's own partition (I think that will break script since mkinitcpio only has a usr module)
* Add disk encryption
* Figure out how to enable browser addons instead of just installing them
* Switch to Syslinux instead of GRUB
* Try Dracut and give it a try. If simpler/better, switch to that instead of mkinitcpio
