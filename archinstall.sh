#!/bin/sh

_gitdir='Input directory where this repo was cloned into: '
#gitdir=
_disk='Input target disk to install Linux: '
#disk=
_timezone='Input your timezone (as in /usr/share/zoneinfo/): '
#timezone=
_hostname='Input system long hostname: '
#hostname=
_rootpass='Input root password: '
#rootpass=
_user='Input username (added to :wheel): '
#user=
_usergecos='Input user GECOS field: '
#usergecos=
_userpass='Input user password: '
#userpass=

# Comment out the next line if you want DHCP to control your DNS
force_dns="1.1.1.1 9.9.9.9"

# Comment out this variable to disable LibreWolf browser installation
librewolf_addons="ublock-origin sponsorblock istilldontcareaboutcookies
clearurls darkreader complete-black-theme-for-firef"

netcheck() {
	printf "%s" "Checking network connection..."
	if ping -c 1 archlinux.org >/dev/null 2>&1; then
		printf "%s\n" " ok"
	elif ping -c 1 1.1.1.1 >/dev/null 2>&1; then
		printf "\n%s\n" "DNS potentially is not working, exiting." >&2
		exit 2
	else
		printf "%s\n" \
			" ping failed, exiting." >&2
		exit 3
	fi
}

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

autosize() {
	case "$2" in
		total) base="$storage";;
		free) base="$free"
			min=0
			max="$storage";;
	esac
	gibi=$((base / $3))
	min="$4"
	case "$5" in
		NULL);;
		*) max="$5";;
	esac
	if [ "$gibi" -lt "$min" ]; then
		gibi="$min"
	elif [ "$gibi" -gt "$max" ]; then
		gibi="$max"
	# elif $gibi is not a power of 2; then
	elif factor -h "$gibi" | \
		eval '! grep "^$gibi: 2\^[0-9]*$\|^$gibi:$" >/dev/null 2>&1'
		then
		x=1
		while [ "$x" -lt "$gibi" ]; do
			y="$x"
			x=$((x * 2))
		done
		gibi="$y"
	fi
	eval "$1size=$gibi"
	free=$((free - gibi))
}

autodisk() {
	if [ X"$disklabel" = X"gpt" ]; then
		case "$3" in
			# Linux swap
			none|swap) code=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F;;
			# Linux root (x86-64)
			/) code=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709;;
			# Linux extended boot
			/boot) code=BC13C2FF-59E6-4262-A352-B275FD6F7172;;
			# EFI System
			/boot/efi) code=C12A7328-F81F-11D2-BA4B-00A0C93EC93B;;
			# Linux /usr (x86-64)
			/usr) code=8484680C-9521-48C6-9C11-B0720656F69E;;
			# Linux variable data
			/var) code=4D21B016-B534-45C2-A9FB-5C16E091FD2D;;
			# Linux temporary data
			/var/tmp) code=7EC6F557-3BC5-4ACA-B293-16EF5DF639D1;; 
 			# Linux home
			/home) code=773f91ef-66d4-49b5-bd83-d683bf40ad16;;
			# Linux filesystem
			*) code=0FC63DAF-8483-4772-8E79-3D69D8477DE4;;
		esac
	elif [ X"$disklabel" = X"mbr" ]; then
		bootable="-"
		case "$3" in
			none|swap) code=82;;	# Linux swap / Solaris
			/boot) code=0c		# W95 FAT32 (LBA)
				bootable="*";;
			*) code=83;;		# Linux
		esac
	fi
	if [ X"$disklabel" = X"mbr" ] && [ "$partnum" -eq 4 ]; then
		printf "%s\n" ",,05,-;"		# Linux extended
		partnum=$((partnum + 1))
	fi
	size=$(($2 * sectorspergibi))
	printf "%s\n" ",$size,$code,$bootable;"
	partnum=$((partnum + 1))
}

automkfs() {
	if [ X"$disklabel" = X"mbr" ] && [ "$partnum" -eq 4 ]; then
		partnum=$((partnum + 1))
	fi
	case "$4" in
		vfat) mkfs="mkdosfs -n $1 -F 32";;
		swap) mkfs="mkswap -L $1";;
		ext4) mkfs="mkfs.ext4 -L $1";;
	esac
	eval "$mkfs /dev/$diskp$partnum"
	[ -d /mnt"$3" ] || mkdir -p /mnt"$3"
	case "$4" in
		swap) swapon LABEL="$1";;
		*) mount LABEL="$1" /mnt"$3";;
	esac
	partnum=$((partnum + 1))
}

partsuffix() {
	case "$disk" in
		nvme*) diskp="$disk"p;;
		sd*) diskp="$disk";;
	esac
}

# Directory where programs get built inside chroot
# This is also made into user bin's home directory
builddir=/var/builds
# Directory where virtual machine subdirectories are held. Each subdirectory
# must have file `drive' and optionally files `drive2' and `*.iso'
# This is also made into user vm's home directory
vmdir=/var/vm

if [ -d /sys/firmware/efi/efivars ]; then
       	bootmode=efi
	if true; then
		disklabel=gpt
	else
		# Deactivated for now
		disklabel=pmbr
	fi
else
	bootmode=bios
	disklabel=mbr
fi

if [ X"$1" != X"nochroot" ] && [ X"$1" != X"chroot" ]; then
	printf "%s\n" "Syntax error: Usage: $0 {nochroot | chroot}" \
		'Call $1 as nochroot first, then chroot after when prompted.'
	exit 1
elif [ X"$1" = X"nochroot" ]; then
	netcheck
	userquery gitdir disk

	# Gibibytes of storage available on $drive
	# minus 1 gibi for metadata
	storage=$(($(grep "$disk$" /proc/partitions | \
		awk '{print $3}') / 1024 / 1024 - 1))
	free="$storage"
	# Gibibytes of memory available on system
	ram=$(($(grep MemTotal: /proc/meminfo | \
		grep -o '[0-9]*') / 1024 / 1024))

	# The whole autosize section needs to be reworked for better numbers
	# Could not find swap algorithm which took both RAM and storage as input
	swapmax=$((storage / 16))
	# <max> can be NULL (only with `free')
	# autosize() <label>   <total|free>  <denominator>     <min>  <max>
	autosize     swap      total         "$ram"            1      "$swapmax"
	autosize     rootfs    free          4                 8      32
	autosize     boot      total         1024              1      2
	autosize     usr       total         32                4      16
	autosize     usrlocal  total         32                2      16
	autosize     var       total         32                4      32
	autosize     vartmp    total         512               1      4
	autosize     home      free          1                 1      NULL
	if [ X"$bootmode" = X"efi" ]; then
	autosize     ESP       total         1024              1      2
	   _ESP="ESP      $ESPsize      /boot/efi  vfat  rw,noexec,nosuid,nodev             0 2"
	fi
	# If using (P?)MBR, the boot partition should be on a 
	# primary partition so put it within the first three
	printf "%s\n" \
		"swap     $swapsize     none       swap  sw                                 0 0" \
		"rootfs   $rootfssize   /          ext4  rw,noexec,nosuid,nodev             0 1" \
		"boot     $bootsize     /boot      ext4  rw,noexec,nosuid,nodev             0 2" \
		"$_ESP" \
		"usr      $usrsize      /usr       ext4  rw,nodev                           0 2" \
		"usrlocal $usrlocalsize /usr/local ext4  rw,nodev                           0 2" \
		"var      $varsize      /var       ext4  rw,noexec,nosuid,nodev             0 2" \
		"vartmp   $vartmpsize   /var/tmp   ext4  rw,noexec,nosuid,nodev,strictatime 0 2" \
		"home     $homesize     /home      ext4  rw,noexec,nosuid,nodev             0 2" \
		> /tmp/disk

		true > /tmp/disk.rej > /tmp/disk.swap

	_break=0
	regex='^[a-zA-Z]* *[0-9]* *[/a-z]* *\(ext4\|vfat\|swap\) *[a-z,]* *[0-1] *[0-2]'
	while true; do
		printf "%s\n" "# disk: $disk, storage: $storage, memory: $ram" \
			"#" > /tmp/disk.swap
		column --table --table-columns \
			'# <label>,<size>,<mount>,<fs>,<options>,<dump>,<pass>' \
			< /tmp/disk >> /tmp/disk.swap
		free="$storage"
		for number in $(awk '{print $2}' /tmp/disk); do
			free=$((free - number))
		done
		printf "%s\n" "# Free: $free" >> /tmp/disk.swap
		cp /tmp/disk.swap /tmp/disk.bak
		clear
		cat /tmp/disk.swap
		[ "$free" -lt 0 ] && printf "%s\n" "" \
			"WARNING: MORE STORAGE ALLOCATED THAN AVAILABLE" \
			"THIS WILL BREAK SCRIPT"
		if [ -s /tmp/disk.rej ]; then
			printf "%s\n" "" \
				"WARNING: THE REGULAR EXPRESSION:" \
				"$regex"
			if [ "$(wc -l < /tmp/disk.rej)" -gt 1 ]; then
				printf "%s\n" "DID NOT MATCH LINES:"
			else
				printf "%s\n" "DID NOT MATCH LINE:"
			fi
			cat /tmp/disk.rej
		fi
		printf "\n%s" "Are these values ok? [yes/vim] "
		read REPLY
		case "$REPLY" in
			[Yy]*) _break=1;;
			[Vv]*) cat /tmp/disk.swap > /tmp/disk.edit
				if [ -s /tmp/disk.rej ]; then
					printf "%s\n" "" "# Rejects:" \
						>> /tmp/disk.edit
					while read line; do
						printf "%s\n" "#$line"
					done < /tmp/disk.rej >> /tmp/disk.edit
					true > /tmp/disk.rej
				fi
				vim /tmp/disk.edit
				cp /tmp/disk.edit /tmp/disk.swap
		esac
		grep -o "$regex" /tmp/disk.swap > /tmp/disk
		grep -v "^$\|^#\|$regex" /tmp/disk.swap > /tmp/disk.rej
		[ "$_break" -eq 1 ] && break
	done

	printf "%s\n" \
		"Press \`Enter' to wipe partition table and install Linux," \
		"CTRL/C to abort."
	read REPLY

	partsuffix
	sectorsize="$(cat /sys/block/"$disk"/queue/hw_sector_size)"
	sectorspergibi=$((1073741824 / sectorsize))

	sfdisk --delete /dev/"$disk"
	partnum=1
	while read line; do
		eval autodisk "$line"
	done < /tmp/disk | sfdisk -X "$disklabel" /dev/"$disk"

	partnum=1
	while read line; do
		eval automkfs "$line"
	done < /tmp/disk

	sed "s/#ParallelDownloads = 5/ParallelDownloads = 8/" /etc/pacman.conf \
		> /etc/pacman.conf.new
	mv /etc/pacman.conf.new /etc/pacman.conf
	pacman -Sy --noconfirm archlinux-keyring
	system_pkgs="base linux linux-firmware dash grub opendoas git vim"
	network_pkgs="networkmanager openresolv"
	doc_pkgs="man-db man-pages"
	gui_pkgs="alsa-utils picom scrot xclip xclip xdotool xorg-server
	xorg-xdm xorg-xhost xorg-xinit xorg-xrandr xorg-xsetroot xwallpaper
	imlib2 libx11 libxft libxinerama"
	vm_pkgs="bridge-utils qemu-system-x86 qemu-ui-gtk"
	# Xorg log complained about these three not being installed on
	# Framework/Librem 14, spikes CPU if (one or all?) not installed
	video_drivers_pkgs="xf86-video-fbdev xf86-video-intel xf86-video-vesa"
	# Install base-devel dependencies except sudo
	# (we use doas & doas-sudo-shim instead)
	devel_pkgs="$(pacman -Si base-devel | grep "Depends On" | cut -d : -f 2 | \
		sed "s/sudo//")"
	[ X"$bootmode" = X"efi" ] && uefi_pkgs=efibootmgr
	[ -z "$librewolf_addons" ] || browser_pkgs="unzip"
	pacstrap /mnt $system_pkgs $network_pkgs $doc_pkgs $gui_pkgs $vm_pkgs \
		$video_drivers_pkgs $devel_pkgs $uefi_pkgs $browser_pkgs
	pacstatus="$?"
	if [ "$pacstatus" -eq 0 ]; then
		printf "%s\n" "" "pacstrap completed!" \
			"Copying files, git cloning, and making fstab..." ""
	else
		printf "%s\n" "" \
			"pacstrap failed with exit $pacstatus." \
			"Reboot and try script again. Sorry!" >&2
		exit 4
	fi

	cp "$0" /mnt
	# We need $disk in chroot also, don't ask user twice
	sed "s/^[#]\{0,\}disk=$/disk=$disk/" /mnt/"$0" > /mnt/"$0".new
	mv /mnt/"$0".new /mnt/"$0"
	chmod 740 /mnt/"$0"
	cp "$gitdir"/usr.local.bin/* /mnt/usr/local/bin
	mkdir /mnt/etc/skel/.sfeed
	if [ -n "$librewolf_addons" ]; then
		mkdir -p /mnt/etc/skel/.librewolf/defaultp.default/extensions
		cp -r "$gitdir"/etc/skel/dotlibrewolf/* /mnt/etc/skel/.librewolf
	fi
	# Copy files into /mnt/etc
	for file in $(find "$gitdir"/etc/ -type f | grep -v librewolf | \
		grep -o '/etc/.*' | tr "\n" " "); do 
		newfile="$(printf "%s" "$file" | sed "s/\/dot/\/./")"
		cp "$gitdir$file" /mnt"$newfile"
	done
	chmod 0400 /mnt/etc/doas.conf
	rm /mnt/etc/bash.bash_logout
	builddir=/mnt"$builddir"
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

	awk '{print "LABEL="$1, $3, $4, $5, $6, $7}' /tmp/disk | \
		column --table --table-columns \
		'# <filesystem>,<mount>,<type>,<options>,<dump>,<pass>' > /mnt/etc/fstab
	#genfstab -L /mnt > /mnt/etc/fstab

	printf "\n%s" "This part of the script is done." \
		"You will need to call this script from within the chroot with \$1 as chroot," \
		"ie. \`/archinstall.sh chroot'" \
		"Press enter to arch-chroot." ""
	read REPLY 
	exec arch-chroot /mnt
elif [ X"$1" = X"chroot" ]; then
	netcheck
	userquery disk timezone hostname rootpass user usergecos userpass 

	if [ -n "$force_dns" ]; then
		dnsconf="/etc/NetworkManager/conf.d/dns-servers.conf"
		printf "%s\n%s" "[global-dns-domain-*]" "servers=" > "$dnsconf"
		for nameserver in $force_dns; do
			printf "%s" "$nameserver,"
		done | sed "s/.$/\n/" >> "$dnsconf"
	fi

	if [ -n "$librewolf_addons" ]; then
		librewolf="librewolf-bin"
		librewolfpath=/etc/skel/.librewolf
		chmod -R 700 "$librewolfpath"
		chmod 755 "$librewolfpath"/defaultp.default/extensions
		chmod 600 "$librewolfpath"/defaultp.default/user.js
		chmod 644 "$librewolfpath"/profiles.ini
		cd "$librewolfpath"/defaultp.default/extensions
		printf "\n%s\n" "Downloading LibreWolf extensions..."
		for addon in $librewolf_addons; do
			curl -o "$addon" "$(curl \
				"https://addons.mozilla.org/en-US/firefox/addon/$addon/" | \
				grep -o \
				'https://addons.mozilla.org/firefox/downloads/file/[^"]*')"
			newxpiname="$(unzip -p "$addon" manifest.json | \
				grep '"id"' | cut -d \" -f 4)"
			mv "$addon" "$newxpiname".xpi
		done
	fi

	sed "s/#ParallelDownloads = 5/ParallelDownloads = 4/" /etc/pacman.conf \
		> /etc/pacman.conf.new
	mv /etc/pacman.conf.new /etc/pacman.conf

	ln -fs /usr/share/zoneinfo/"$timezone" /etc/localtime

	printf "%s\n" "$hostname" > /etc/hostname
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
	
	alias yay="setpriv --reuid=bin --regid=bin --clear-groups --reset-env yay"
	alias makepkg="setpriv --reuid=bin --regid=bin --clear-groups makepkg"
	EOF

	# Build stuff as bin user, see /etc/doas.conf
	# and /var/builds/.config/yay/config.json
	usermod -c "system build user" -d "$builddir" bin

	chown -R root:bin "$builddir"
	find "$builddir" -perm 644 -execdir chmod 664 {} +
	find "$builddir" -perm 755 -execdir chmod 775 {} +

	# Create a user for vm.sh to run QEMU
	useradd -c "vm.sh user" -d "$vmdir" -p "!*" -r -s /usr/bin/nologin vm
	# If user backed up virtual machines, give correct perms for vm.sh
	chown -R root:vm "$vmdir"
	find "$vmdir" -type d -execdir chmod 770 {} + || chmod -R 770 "$vmdir"
	find "$vmdir" -type f -name "*.iso" -execdir chmod 440 {} +
	find "$vmdir" -type f \( -name drive -o -name drive2 \) \
		-execdir chmod 660 {} +

	for skeletons in documents downloads images .passwords; do
		mkdir /etc/skel/"$skeletons"
	done

	useradd -c "$usergecos" -G wheel,vm -m "$user"
	printf "%s\n" "$user:$userpass" | chpasswd

	pwck -s
	grpck -s

	# Accounts already locked
	getent shadow bin vm

	# Create temp sudo link to prevent asking for root password
	# since doas-sudo-shim has not been installed yet
	ln -s /usr/bin/doas /usr/local/bin/sudo
	cd "$builddir"/yay-bin && setpriv --reuid=bin --regid=bin --clear-groups \
		makepkg --noconfirm -ci
	rm /usr/local/bin/sudo
	# doas.conf only works when full pacman path is set with yay --save
	# also doas.conf must have full pacman path or else permission denied
	setpriv --reuid=bin --regid=bin --clear-groups --reset-env \
		yay --save --pacman /usr/bin/pacman
	setpriv --reuid=bin --regid=bin --clear-groups --reset-env \
		yay --save --sudo doas
	setpriv --reuid=bin --regid=bin --clear-groups --reset-env \
		yay --removemake --noconfirm -S \
		devour $librewolf otf-san-francisco-mono doas-sudo-shim xbanish

	for srcdir in dwm dmenu st tabbed slock sfeed herbe; do
		cd "$builddir/$srcdir"
		patch -p 1 < "$builddir/$srcdir/$srcdir-archdesktop.diff"
		make
		make install
	done

	# If /usr is on its own partition, add usr module to mkinitcpio
	if awk '{print $2}' /etc/fstab | grep '/usr\($\|/$\)' >/dev/null 2>&1
	then
		grep -v '\(^#\|^$\)' /etc/mkinitcpio.conf | \
			sed "s/fsck/fsck usr/" > /etc/mkinitcpio.conf.new
		mv /etc/mkinitcpio.conf.new /etc/mkinitcpio.conf
		mkinitcpio -P
	fi

	partsuffix
	if [ X"$bootmode" = X"bios" ]; then
		# Fix me
		grub-install --target=i386-pc /dev/"$diskp"1
	elif [ X"$bootmode" = X"efi" ]; then
		grub-install --target=x86_64-efi --efi-directory=/boot/efi \
			--bootloader-id="Arch Linux"
	fi
	# Change GRUB font size; `videoinfo' in GRUB CLI to see possible numbers
	sed "s/GRUB_GFXMODE=auto/GRUB_GFXMODE=640x480/" /etc/default/grub \
		> /etc/default/grub.new
	mv /etc/default/grub.new /etc/default/grub
	grub-mkconfig -o /boot/grub/grub.cfg

	mkdir -p /etc/systemd/system/tmp.mount.d
	cat <<- EOF > /etc/systemd/system/tmp.mount.d/override.conf
	[Mount]
	Options=mode=1777,strictatime,nosuid,nodev,size=50%%,nr_inodes=1m,noexec
	EOF

	systemctl enable NetworkManager.service xdm.service

	printf "%s\n" "" "Arch Linux installation script completed." \
		"Exit chroot and reboot."
	exit 0
fi
