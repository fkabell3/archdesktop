# To Do/Bugs

* Add disk encryption
* Add LVM
* Give partitioning warning when /usr/bin is on it's own partition (I think that will break script since mkinitcpio only has a usr module (edit: using Dracut but still need to test))
* Figure out how to enable browser addons instead of just installing them
* Switch to booster initramfs generator instead of dracut. Maybe give user a choice.
* Document everything, patch the dwm, dmenu, etc man pages.
* If feasible, port script to Artix Linux (one script, not seperate for each OS). We don't want to contribute to this madness by only supporting systemd.
* Port script to ARM

# Completed!
* Add MBR/GUID codes (search for $code, used with sfdisk)
* Change vm.sh overuse of `su -c' to runuser(1) (edit: used setpriv(1) instead), and then take make vm's shell nologin for more priviledge seperation
* Split dmenu_launcher's System catagory into Display and System. Display will have screenshotting, brightness control, and screen lock.
* Troubleshoot MBR (currently broken, or at least doesn't work in QEMU) (edit: found issue: grub-install assumes partition 1, still need to fix, edit: fixed when swapping to Limine)
* Switch to Syslinux instead of GRUB (edit: used Limine instead)
* Try Dracut and give it a try. If simpler/better, switch to that instead of mkinitcpio
