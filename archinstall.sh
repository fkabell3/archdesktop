#!/bin/sh

_timezone='Input your timezone (as in /usr/share/zoneinfo/): '
#timezone=
_hostname='Input system long hostname: '
#hostname=
_gitdir='Input directory where this repo was cloned into: '
#gitdir=
_disk='Input target disk to install Arch Linux: '
#disk=
_rootpass='Input root password: '
#rootpass=
_user='Input username (added to :wheel): '
#user=
_usergecos='Input user GECOS field: '
#usergecos=
_userpass='Input user password: '
#userpass=

userquery() {
	printf "%s\n" "Note: variables do not get checked."
	for var in "$@"; do
		if [ -z "$(eval printf "%s" "\$$var")" ]; then
			if [ X"$var" = X"disk" ]; then
				printf "%s\n" \
					"(loop devices & partitions not shown)"
				lsblk -o NAME,SIZE,TYPE -e 7 | grep -v part
			fi
			eval set -- "\$_$var"
			printf "%s " "$@"
			read REPLY
			eval "$var"=\'"$REPLY"\'
		fi
	done
}

netcheck() {
	if ping -c 1 archlinux.org >/dev/null 2>&1; then
		printf "%s\n" "Network is working."
	elif ping -c 1 1.1.1.1 >/dev/null 2>&1; then
		printf "%s\n" "DNS potentially could not be working." \
			"Exiting..."
		exit 2
	else
		printf "%s\n" \
			"Make sure you have a working internet connection." \
			"(ping failed)"
			"Exiting..."
		exit 3
	fi
}

partsuffix() {
	case "$disk" in
		nvme*) diskp="$disk"p;;
		sd*) diskp="$disk";;
	esac
}

# Usage: automkfs <label>
automkfs() {
	case "$1" in
		# FAT filesystem labels should be uppercase
		BOOT) fs="vfat"
			mount="/mnt/boot"
			options="defaults"
			partnum=1
			dump=0
			pass=2;;
		swap) fs="$1"
			mount="$1"
			options="defaults"
			partnum=2
			dump=0
			pass=0;;
		rootfs) fs="ext4"
			mount="/mnt"
			options="defaults"
			partnum=3
			dump=0
			pass=1;;
		home) fs="ext4"
			mount="/mnt/$1"
			options="defaults"
			partnum=5
			dump=0
			pass=2;;
	esac 
	case "$fs" in
		vfat) mkfs="mkdosfs -n $1 -F 32";;
		swap) mkfs="mkswap -L $1";;
		ext4) mkfs="mkfs.ext4 -L $1";;
	esac
	eval "$mkfs /dev/$diskp$partnum"
	case "$1" in
		swap) swapon LABEL="$1";;
		*) [ -d "$mount" ] || mkdir "$mount"
			mount LABEL="$1" "$mount";;
	esac
	label="$(blkid | grep "^/dev/$diskp$partnum" | \
		cut -d " " -f 2 | cut -d \" -f 2)"
	[ -d /mnt/etc ] || mkdir /mnt/etc
	mount="$(printf "%s" "$mount" | sed "s/\/mnt//")"
	# genfstab(8) is also available
	printf "%s\n" "LABEL=$label $mount $fs $options $dump $pass" \
		>> /mnt/etc/fstab
} 

# Directory where programs get built inside chroot
# This is also made into user bin's home directory
builddir=/var/builds
# Directory where virtual machine subdirectories are held. Each subdirectory
# must have file `drive' and optionally files `drive2' and `*.iso'
# This is also made into user vm's home directory
vmdir=/var/vm

if [ -d /sys/firmware/efi ]; then
       	bootmode=EFI
else
	bootmode=BIOS
fi

if [ X"$1" != X"nochroot" ] && [ X"$1" != X"chroot" ]; then
	printf "%s\n" "Syntax error: Usage: $0 {nochroot | chroot}" \
		'Call $1 as nochroot first, then chroot after when prompted.'
	exit 1
elif [ X"$1" = X"nochroot" ]; then
	netcheck
	userquery hostname gitdir disk
	echo $diskp
	builddir=/mnt"$builddir"

	printf "\n"
	while true; do
		printf "%s\n" "Time to partition your disk." \
			"This script expects four partitions:" \
			">> /boot(1), swap(2), / [rootfs](3), and /home(5)." \
			"Make sure they are in that order." \
			"GRUB does not make use of the boot flag." \
			"And note that this system is using $bootmode."
				fdisk /dev/"$disk"
				clear
				lsblk -o NAME,SIZE,TYPE -e 7
				printf "%s" "Are you done partitioning? "
				read REPLY
				case "$REPLY" in 
					[Yy]*) break;;
				esac 
	done
	partsuffix
	# rootfs must be mounted first excluding swap
	for part in rootfs BOOT swap home; do
		automkfs "$part"
	done
	#genfstab -U /mnt > /mnt/etc/fstab

	pacman -Sy --noconfirm archlinux-keyring
	pacstrap /mnt base linux linux-firmware alsa-utils bridge-utils dash \
		git go grub imlib2 libx11 libxft libxinerama man-db man-pages \
		mupdf networkmanager opendoas openresolv picom qemu-system-x86 \
		qemu-ui-gtk scrot vim xclip xdotool xorg-server xorg-xdm \
		xorg-xhost xorg-xinit xorg-xsetroot xwallpaper \
		xf86-video-fbdev xf86-video-intel xf86-video-vesa 
	# Xorg log complained about these three not being installed on
	# Librem 14 & Framework; Spike CPU usage if one or all? not installed

	# Download all packages in base-devel except sudo
	pacman -Si base-devel | grep "Depends On" | cut -d : -f 2 | \
		sed s/sudo// | xargs pacstrap /mnt
	[ X"$bootmode" = X"EFI" ] && pacstrap /mnt efibootmgr
	printf "%s\n" "pacstrap completed!" "Copying files and git cloning..."

	cp "$0" /mnt
	# Carry $disk into chroot so to not prompt user twice
	sed "s/^[#]\{0,\}disk=$/disk=$disk/" /mnt/"$0" > /mnt/"$0".new
	mv /mnt/"$0".new /mnt/"$0"
	chmod 740 /mnt/"$0"
	cp "$gitdir"/usr.local.bin/* /mnt/usr/local/bin
	# Copy files into /mnt/etc, skip files in "$gitdir"/etc/skel since
	# they are named differently (eg. dotsfeed instead of .sfeed)
	for file in $(find "$gitdir"/etc/ -type f | grep -v skel | \
		grep -o '/etc/.*' | tr "\n" " "); do 
		cp "$gitdir$file" "/mnt/$file"
	done
	chmod 0400 /mnt/etc/doas.conf
	rm /mnt/etc/bash.bash_logout
	mkdir -p /mnt"$vmdir" "$builddir" \
		/mnt/usr/local/share/backgrounds /mnt/etc/skel/.sfeed
	cp "$gitdir"/etc/skel/dotsfeed/sfeedrc /mnt/etc/skel/.sfeed/sfeedrc
	rm /mnt/etc/skel/.bash*
	for srcdir in dwm dmenu st tabbed slock; do
		git -C "$builddir" clone --depth 1 https://git.suckless.org/"$srcdir"
		cp "$gitdir"/patches/"$srcdir"-archdesktop.diff "$builddir/$srcdir"
	done
	git -C "$builddir" clone --depth 1 https://github.com/dudik/herbe
	cp "$gitdir"/patches/herbe-archdesktop.diff "$builddir"/herbe
	git -C "$builddir" clone --depth 1 git://git.codemadness.org/sfeed
	cp "$gitdir"/patches/sfeed-archdesktop.diff "$builddir"/sfeed
	git -C "$builddir" clone --depth 1 https://aur.archlinux.org/yay-bin.git

	printf "\n%s" "This part of the script is done." \
		"You will need to call this script from within the chroot with \$1 as chroot," \
		"ie. \`/archinstall.sh chroot'" \
		"Press enter to arch-chroot." ""
	read REPLY 
	exec arch-chroot /mnt
elif [ X"$1" = X"chroot" ]; then
	netcheck
	userquery disk rootpass user usergecos userpass 
	
	printf "%s\n" "$hostname" > /etc/hostname
	ln -sf /usr/share/zoneinfo/"$timezone" /etc/localtime
	hwclock --systohc
	sed "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen \
		> /etc/locale.gen.new
	mv /etc/locale.gen.new /etc/locale.gen
	locale-gen
	printf "%s\n" "LANG=en_US.UTF-8" > /etc/locale.conf
	map=/usr/share/kbd/keymaps/i386/qwerty/us.map
	gzip -d "$map".gz
	sed "s/1 = Escape/1 = Caps_Lock/" "$map" > "$map".new
	mv "$map".new "$map"
	sed "s/58 = Caps_Lock/58 = Escape/" "$map" > "$map".new
	mv "$map".new "$map"
	gzip "$map"
	printf "%s\n" "KEYMAP=$map.gz" > /etc/vconsole.conf

	ln -fs /bin/dash /bin/sh
	rm /etc/xdg/picom.conf

	printf "%s\n" root:"$rootpass" | chpasswd
	cat <<- EOF > /root/.bashrc
	# /root/.bashrc
	
	alias makepkg="runuser -u bin -- makepkg"
	alias yay="runuser -u bin -- yay"
	EOF
	# Build stuff as bin user, see /etc/doas.conf
	# and /var/builds/.config/yay/config.json
	usermod -c "system build user" -d "$builddir" bin

	# Create a user for vm.sh to run QEMU
	# todo: replace vm.sh script from 
	# su to doas/runuser and then take away shell
	useradd -c "vm.sh user" -d "$vmdir" -r -s /bin/sh vm
	# If user backed up virtual machines, give correct perms for vm.sh
	chown -R root:vm "$vmdir"
	find "$vmdir" -type d -execdir chmod 770 {} + || chmod -R 770 "$vmdir"
	find "$vmdir" -type f -name "*.iso" -execdir chmod 440 {} +
	find "$vmdir" -type f \( -name drive -o -name drive2 \) \
		-execdir chmod 660 {} +

	for skeletons in documents downloads images; do
		mkdir /etc/skel/"$skeletons"
	done

	useradd -c "$usergecos" -G wheel,network,vm -m "$user"
	printf "%s\n" "$user:$userpass" | chpasswd

	pwck -s
	grpck -s

	# Accounts already locked
	getent shadow bin vm

	chown -R root:bin "$builddir"
	find "$builddir" -perm 644 -execdir chmod 664 {} +
	find "$builddir" -perm 755 -execdir chmod 775 {} +
	# Create temp sudo link to prevent asking for root password
	# since doas-sudo-shim has not been installed yet
	ln -s /usr/bin/doas /usr/local/bin/sudo
	export builddir
	(cd "$builddir"/yay-bin && runuser -u bin -- makepkg --noconfirm -ci)
	rm /usr/local/bin/sudo
	# doas.conf only works when full pacman path is set with yay --save
	# also doas.conf must have full pacman path or else permission denied
	runuser -u bin -- yay --save --pacman /usr/bin/pacman
	runuser -u bin -- yay --save --sudo doas
	runuser -u bin -- yay --removemake --noconfirm -S devour librewolf-bin \
		otf-san-francisco-mono doas-sudo-shim xbanish
	for srcdir in dwm dmenu st tabbed slock sfeed herbe; do
		cd "$builddir/$srcdir"
		patch -p 1 < "$builddir/$srcdir/$srcdir-archdesktop.diff"
		make
		rm "$builddir/$srcdir"/config.h
		make install
	done

	mkinitcpio -P
	partsuffix
	if [ X"$bootmode" = X"BIOS" ]; then
		# automkfs() function defined 
		# partition 1 as the boot partition
		grub-install --target=i386-pc /dev/"$diskp"1
	elif [ X"$bootmode" = X"EFI" ]; then
		grub-install --target=x86_64-efi --efi-directory=/boot/ \
			--bootloader-id="Arch Linux"
	else
		printf "\n%s\n" \
			"Error: GRUB did not install to /dev/$diskp""1!"
	fi
	# Change GRUB font size; `videoinfo' in GRUB CLI to see possible numbers
	#sed "s/GRUB_GFXMODE=auto/GRUB_GFXMODE=640x480/" /etc/default/grub \
		#> /etc/default/grub.new
	#mv /etc/default/grub.new /etc/default/grub
	grub-mkconfig -o /boot/grub/grub.cfg

	systemctl enable NetworkManager.service xdm.service

	printf "%s\n" "" "Arch Linux installation script completed." \
		"Exit chroot and reboot."
	exit 0
fi
