#!/bin/sh
set -e

# Ignore if downloaded with curl(1)
_gitdir='Input directory where this repo was cloned into: '
#gitdir=

_disk='Input target disk to install Linux: '
#disk=

# Ignore if using BIOS which unconditionally uses MBR/Limine
# A) PMBR & Limine bootloader
# B) GPT  & Limine bootloader
# C) GPT  & EFI stub with unified kernel image with bootsplash
_eficonf='Your choice [a/b/C]: '
#eficonf=

_timezone='Input timezone (as in /usr/share/zoneinfo/): '
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

# Every variable we need inside the chroot
chrootvars='disk disklabel bootloader bootpart timezone hostname rootpass user
usergecos userpass pixels perpx fontsize'

# Arbitrary additional user packages
local_pkgs='vim mupdf'

# Comment out the next line if you want DHCP to control your DNS
force_dns='1.1.1.1 9.9.9.9'

# The kernel command line
kernelcmdline='root=LABEL=rootfs rw resume=LABEL=swap quiet bgrt_disable'

# Comment out this variable to disable LibreWolf browser installation
librewolf_addons='ublock-origin sponsorblock istilldontcareaboutcookies
clearurls darkreader complete-black-theme-for-firef'

# Note: Caps Lock and Escape are swapped
# This and the locale have not been tested when changed
keymap='/usr/share/kbd/keymaps/i386/qwerty/us.map'

# Directory where programs get built inside chroot
# This is also made into user bin's home directory
builddir='/var/builds'
# Directory where virtual machine subdirectories are held
# This is also made into user vm's home directory
vmdir='/var/vm'

die() {
	printf '%s %s\n' 'Fatal:' "$@" >&2
	exit 1
}

netcheck() {
	printf '%s' 'Checking network connection...'
	if ping -c 1 archlinux.org > /dev/null 2>&1; then
		printf '%s\n' ' ok'
	else
		printf '\n'
		if ping -c 1 1.1.1.1 > /dev/null 2>&1; then
			die 'DNS potentially is not working.'
		else
			die 'ping(8) failed.'
		fi
	fi
}

userquery() {
	for var in "$@"; do
		if [ -z "$(eval printf '%s' "\$$var")" ]; then
			eval set -- "\$_$var"
			for description in "$@"; do
				printf '%s ' "$description"
			done
			read REPLY
			eval "$var"=\'"$REPLY"\'
		fi
	done
}

chrootvars() {
	for var in $chrootvars; do
		printf '%s ' "$var=\"$(eval printf '%s' "\"\$$var\"")\""
	done
}

autosize() {
	case "$2" in
		total)
			base="$storage"
		;;
		free)
			base="$free"
			min=0
			max="$storage"
		;;
	esac
	gibi=$((base / $3))
	min="$4"
	case "$5" in
		NULL);;
		*)
			max="$5"
		;;
	esac
	if [ "$gibi" -lt "$min" ]; then
		gibi="$min"
	elif [ "$gibi" -gt "$max" ]; then
		gibi="$max"
	# elif $gibi is not a power of 2; then
	elif factor -h "$gibi" | \
		eval '! grep "^$gibi: 2\^[0-9]*$\|^$gibi:$" > /dev/null 2>&1'
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
	if [ X"$disklabel" = X'gpt' ]; then
		case "$3" in
			none|swap) # Linux swap
			code=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
			;;
			/) # Linux root (x86-64)
			code=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
			;;
			/boot) # Linux extended boot
			code=BC13C2FF-59E6-4262-A352-B275FD6F7172
			;;
			# Commented out to prevent systemd from
			# automounting to /efi, thus overriding fstab
			#/boot/efi) # EFI System
			#code=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
			#;;
			/usr) # Linux /usr (x86-64)
			code=8484680C-9521-48C6-9C11-B0720656F69E
			;;
			/var) # Linux variable data
			code=4D21B016-B534-45C2-A9FB-5C16E091FD2D
			;;
			/var/tmp) # Linux temporary data
			code=7EC6F557-3BC5-4ACA-B293-16EF5DF639D1
			;; 
			/home) # Linux home
			code=773F91Ef-66D4-49B5-BD83-D683BF40AD16
			;;
			*) # Linux filesystem
			code=0FC63DAF-8483-4772-8E79-3D69D8477DE4
			;;
		esac
	elif [ X"$disklabel" = X'mbr' ]; then
		bootable='-'
		case "$3" in
			none|swap) # Linux swap / Solaris
				code=82
			;;
			/boot) # W95 FAT32 (LBA)
				code=0c
				bootable='*'
			;;
			/boot/efi) # EFI (FAT-12/16/32)
				code=ef
			;;
			*) # Linux
				code=83
			;;
		esac
		if [ "$partnum" -eq 4 ]; then
			printf '%s\n' ',,05,-;'	# Extended
			partnum=$((partnum + 1))
		fi
	fi
	size=$(($2 * sectorspergibi))
	printf '%s\n' ",$size,$code,$bootable;"
	partnum=$((partnum + 1))
}

automkfs() {
	if [ X"$disklabel" = X'mbr' ] && [ "$partnum" -eq 4 ]; then
		partnum=$((partnum + 1))
	fi
	case "$4" in
		vfat)
			mkfs="mkdosfs -n $1 -F 32"
		;;
		swap)
			mkfs="mkswap -L $1"
		;;
		ext4)
			mkfs="mkfs.ext4 -L $1"
		;;
	esac
	# Linux kernel inserts `p' between the whole block device name and the 
	# partition number if the whole block device name ends with a digit
	case "$disk" in
		*[0-9])
			diskp="$disk"p
		;;
		*)
			diskp="$disk"
		;;
	esac
	eval "$mkfs /dev/$diskp$partnum"
	[ -d /mnt"$3" ] || mkdir -p /mnt"$3"
	case "$4" in
		swap)
			swapon LABEL="$1"
		;;
		*)
			mount LABEL="$1" /mnt"$3"
		;;
	esac
	partnum=$((partnum + 1))
}

# sed -i is nonportable
sed_i() {
	file="$(eval printf '%s' \$"$#")"
	set -- \
		"$(for var in "$@"; do
			[ "$1" != "$file" ] && printf '%s ' "$var"
			shift
		done)"
	sed "$@" "$file" > "$file".new
	mv "$file".new "$file"
}

if [ -d /sys/firmware/efi/efivars ]; then
       	bootmode=efi
else
	bootmode=bios
	disklabel=mbr
	bootloader=limine
fi

if [ -z "$1" ]; then
	if ! which pacstrap > /dev/null 2>&1; then
		die 'pacstrap(8) not found.'
	fi
	netcheck
	if ! which git > /dev/null 2>&1; then
		printf '%s\n' 'git(1) not found, installing...'
		pacman --noconfirm -Sy git || var="$?"
		if [ "$var" -ne 0 ]; then
			pkill gpg-agent || true
			rm -rf /etc/pacman.d/gnupg/*
			pacman-key --init
			pacman-key --populate
			pacman --noconfirm -Sy git
		fi
	fi

	if [ X"$(basename "$PWD")" = X'archdesktop' ]; then
		gitdir="$PWD"
	elif [ -d "$PWD"/archdesktop ]; then
		gitdir="$PWD"/archdesktop
	else
		git clone --depth 1 \
			https://github.com/fkabell3/archdesktop || \
			die "git clone failed."
		gitdir="$PWD"/archdesktop
	fi
	clear

	printf '%s\n%s\n\n' 'Note: variables do not get error checked.' \
		'set -e is enabled so script will just exit on any failures.'
	if [ -z "$disk" ]; then
		printf '%s\n' '(loop devices & partitions not shown)'
		lsblk -o NAME,RM,SIZE,TYPE -e 7 | grep -v part
		userquery disk
	fi
	if [ X"$bootmode" = X"efi" ]; then
		printf '%s\n' 'You are using EFI. Select a configuration:'
		printf '\t%s\n' 'A) PMBR & Limine bootloader' \
				'B) GPT  & Limine bootloader' \
				'C) GPT  & EFI stub with unified kernel image and bootsplash'
		userquery eficonf
		case "$eficonf" in
			[Bb]*)
				disklabel=gpt
				bootloader=limine
			;;
			[Cc]*)
				disklabel=gpt
				bootloader=efistub
			;;
			*)
				disklabel=mbr # PMBR
				bootloader=limine
			;;
		esac
	fi
	userquery timezone hostname rootpass user usergecos userpass 

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
	autosize     rootfs    free          4                 8      32
	autosize     boot      total         1024              1      2
	autosize     usr       total         32                4      16
	autosize     usrlocal  total         32                2      16
	autosize     var       total         32                4      32
	autosize     vartmp    total         512               1      4
	autosize     home      free          1                 1      NULL
	autosize     swap      total         "$ram"            1      "$swapmax"
	if [ X"$bootmode" = X'efi' ]; then
	autosize     ESP       total         1024              1      2
	   _ESP="ESP      $ESPsize      /boot/efi  vfat  rw,noexec,nosuid,nodev 0 2"
	fi

	# For (P)MBR, the boot partition & ESP should be on a
	# primary partition so put it within the first three
	printf '%s\n' \
		"rootfs   $rootfssize   /          ext4  rw,noexec,nosuid,nodev 0 1" \
		"boot     $bootsize     /boot      ext4  rw,noexec,nosuid,nodev 0 2" \
		"$_ESP" \
		"usr      $usrsize      /usr       ext4  rw,nodev               0 2" \
		"usrlocal $usrlocalsize /usr/local ext4  rw,nodev               0 2" \
		"var      $varsize      /var       ext4  rw,noexec,nosuid,nodev 0 2" \
		"vartmp   $vartmpsize   /var/tmp   ext4  rw,noexec,nosuid,nodev 0 2" \
		"home     $homesize     /home      ext4  rw,noexec,nosuid,nodev 0 2" \
		"swap     $swapsize     none       swap  sw                     0 0" \
		> /tmp/disk

		true > /tmp/disk.rej > /tmp/disk.swap

	_break=0
	regex='^[a-zA-Z]* *[0-9]* *[/a-z]* *\(ext4\|vfat\|swap\) *[a-z,]* *[0-1] *[0-2]'
	while true; do
		printf '%s\n' "# disk: $disk, storage: $storage, memory: $ram" \
			'#' > /tmp/disk.swap
		column --table --table-columns \
			'# <label>,<size>,<mount>,<fs>,<options>,<dump>,<pass>' \
			< /tmp/disk >> /tmp/disk.swap
		free="$storage"
		for number in $(awk '{print $2}' /tmp/disk); do
			free=$((free - number))
		done
		printf '%s\n' "# Free: $free" >> /tmp/disk.swap
		cp /tmp/disk.swap /tmp/disk.bak
		clear
		cat /tmp/disk.swap
		[ "$free" -lt 0 ] && printf '\n%s\n%s\n' \
			'WARNING: MORE STORAGE ALLOCATED THAN AVAILABLE' \
			'THIS WILL BREAK SCRIPT'
		if [ -s /tmp/disk.rej ]; then
			printf '\n%s\n%s\n' 'WARNING: THE REGULAR EXPRESSION:' \
				"$regex"
			printf '%s' 'DID NOT MATCH LINE'
			[ "$(wc -l < /tmp/disk.rej)" -gt 1 ] && printf '%s' 'S'
			printf '%s\n' ':'
			cat /tmp/disk.rej
		fi
		printf '\n%s' 'Are these values ok? [yes/vim] '
		read REPLY
		case "$REPLY" in
			[Yy]*)
				_break=1
			;;
			[Vv]*)
				cat /tmp/disk.swap > /tmp/disk.edit
				if [ -s /tmp/disk.rej ]; then
					printf '\n%s\n' '# Rejects:' \
						>> /tmp/disk.edit
					while read line; do
						printf '%s\n' "#$line"
					done < /tmp/disk.rej >> /tmp/disk.edit
					true > /tmp/disk.rej
				fi
				vim /tmp/disk.edit
				cp /tmp/disk.edit /tmp/disk.swap
			;;
		esac
		grep -o "$regex" /tmp/disk.swap > /tmp/disk
		grep -v "^$\|^#\|$regex" /tmp/disk.swap > /tmp/disk.rej || true
		[ "$_break" -eq 1 ] && break
	done

	printf '%s\n' \
		'Press ENTER to wipe partition table and install Linux,' \
		'CTRL/C to abort.'
	read REPLY

	sectorsize="$(cat /sys/block/"$disk"/queue/hw_sector_size)"
	sectorspergibi=$((1073741824 / sectorsize))

	sfdisk --delete /dev/"$disk"
	partnum=1
	while read line; do
		eval "autodisk $line"
	done < /tmp/disk | sfdisk -X "$disklabel" /dev/"$disk"

	partnum=1
	while read line; do
		eval "automkfs $line"
	done < /tmp/disk

	sed_i 's/#ParallelDownloads = 5/ParallelDownloads = 8/' /etc/pacman.conf
	pacman -Sy --noconfirm archlinux-keyring
	system_pkgs='base linux linux-firmware dracut dash opendoas git'
	network_pkgs='networkmanager openresolv'
	doc_pkgs='man-db man-pages'
	gui_pkgs='alsa-utils picom scrot xclip xclip xdotool xorg-server
	xorg-xdm xorg-xhost xorg-xinit xorg-xrandr xorg-xsetroot xwallpaper
	imlib2 libx11 libxft libxinerama'
	console_pkgs='terminus-font gpm'
	vm_pkgs='qemu-system-x86 qemu-ui-gtk bridge-utils'
	# Install base-devel dependencies except sudo
	# (we use doas & doas-sudo-shim instead)
	devel_pkgs="$(pacman -Si base-devel | grep 'Depends On' | \
		cut -d : -f 2 | sed 's/sudo//')"
	[ -n "$librewolf_addons" ] && browser_pkgs='unzip'
	[ X"$bootmode" = X'efi' ] && efi_pkgs=efibootmgr
	[ X"$bootloader" = X'limine' ] && bootloader_pkgs='limine'
	case "$(lscpu | awk '/^Vendor ID:/ { print $NF }')" in
		*Intel*)
			microcode_pkgs=intel-ucode
		;;
		*AMD*)
			microcode_pkgs=amd-ucode
		;;
	esac
	# Xorg log complained about these three not being installed on
	# Framework/Librem 14, spikes CPU if (one or all?) not installed
	video_drivers_pkgs='xf86-video-fbdev xf86-video-intel xf86-video-vesa'
	pacstrap /mnt $system_pkgs $network_pkgs $doc_pkgs $gui_pkgs $console_pkgs \
		$vm_pkgs $devel_pkgs $browser_pkgs $efi_pkgs $bootloader_pkgs \
		$microcode_pkgs $video_drivers_pkgs $local_pkgs
	pacstatus="$?"
	if [ "$pacstatus" -eq 0 ]; then
		printf '\n%s\n%s\n' 'pacstrap completed!' \
			'Copying files, git cloning, and making fstab...'
	else
		die "pacstrap failed with exit $pacstatus." \
			'Reboot and try script again. Sorry!'
	fi

	cp "$0" /mnt
	chmod 740 /mnt/"$(basename $0)"
	cp "$gitdir/usr.local.bin/"* /mnt/usr/local/bin
	mkdir /mnt/etc/skel/.sfeed
	if [ -n "$librewolf_addons" ]; then
		mkdir -p /mnt/etc/skel/.librewolf/defaultp.default/extensions
		cp -r "$gitdir"/etc/skel/dotlibrewolf/* /mnt/etc/skel/.librewolf
	fi
	# Copy non-browser/pacman files into /mnt/etc
	for file in $(find "$gitdir"/etc/ -type f | \
		grep -v '\(librewolf\|pacman\)' | \
		grep -o '/etc/.*' | tr '\n' ' '); do 
		newfile="$(printf '%s' "$file" | sed 's/\/dot/\/./')"
		cp "$gitdir$file" /mnt"$newfile"
	done
	mkdir /mnt/etc/pacman.d/hooks
	cp "$gitdir"/etc/pacman.d.hooks/10-fsrw.hook /mnt/etc/pacman.d/hooks
	cp "$gitdir"/etc/pacman.d.hooks/30-fsro.hook /mnt/etc/pacman.d/hooks
	[ X"$bootloader" = X'efistub' ] && cp "$gitdir"/linux.bmp \
		/mnt/usr/share/systemd/bootctl
	chmod 0400 /mnt/etc/doas.conf
	rm /mnt/etc/bash.bash_logout
	builddir=/mnt"$builddir"
	mkdir -p /mnt"$vmdir" "$builddir" \
		/mnt/usr/local/share/backgrounds /mnt/etc/skel/.sfeed
	cp "$gitdir"/etc/skel/dotsfeed/sfeedrc /mnt/etc/skel/.sfeed/sfeedrc
	rm /mnt/etc/skel/.bash*
	for srcdir in dwm dmenu st tabbed slock; do
		git -C "$builddir" clone --depth 1 \
			https://git.suckless.org/"$srcdir"
		cp "$gitdir"/patches/"$srcdir"-archdesktop.diff \
			"$builddir/$srcdir"
	done
	git -C "$builddir" clone --depth 1 https://github.com/dudik/herbe
	cp "$gitdir"/patches/herbe-archdesktop.diff "$builddir"/herbe
	git -C "$builddir" clone --depth 1 git://git.codemadness.org/sfeed
	cp "$gitdir"/patches/sfeed-archdesktop.diff "$builddir"/sfeed
	git -C "$builddir" clone --depth 1 https://aur.archlinux.org/yay-bin.git
	awk '{print "LABEL="$1, $3, $4, $5, $6, $7}' /tmp/disk | \
		column --table --table-columns \
		'# <filesystem>,<mount>,<type>,<options>,<dump>,<pass>' \
		> /mnt/etc/fstab

	# cp /tmp/disk /mnt/tmp/disk doesn't work. No idea why.
	bootpart="$(awk '$1 ~ /ESP/ { print NR }' /tmp/disk)"
	if [ X"$disklabel" = X'mbr' ] && [ "$bootpart" -ge 4 ]; then
		bootpart=$((partnum + 1))
	fi

	horizontal="$(cut -d , -f 1 "$(find /sys -name virtual_size 2> /dev/null | \
		head -n 1)")"
	vertical="$(cut -d , -f 2 "$(find /sys -name virtual_size 2> /dev/null | \
		head -n 1)")"
	pixels=$((horizontal * vertical))

	# These next two calculations must be done
	# now since bc(1) is not available inside the chroot

	# Calculate LibreWolf's about:config layout.css.devPixelsPerPx value
	# 1680 x 1050 = 1764000, the base resolution which gets 1 as its value
	perpx="$(printf '%s\n' "scale=2; sqrt($pixels / 1764000)" | bc)"

	# Calculate how big some suckless.org programs will be
	denom=7168
	fontsize="$(printf '%s\n' "sqrt($pixels / $denom)" | bc )"

	printf '\n%s\n' 'Chrooting into /mnt...'
	eval arch-chroot /mnt /bin/sh -c \'$(chrootvars) /"$(basename "$0")" \
		chroot\'
elif [ X"$1" = X'chroot' ]; then
	printf '%s\n' 'Chroot entered successfully!'

	netcheck

	if [ -n "$force_dns" ]; then
		dnsconf='/etc/NetworkManager/conf.d/dns-servers.conf'
		printf '%s\n%s' '[global-dns-domain-*]' 'servers=' > "$dnsconf"
		for nameserver in $force_dns; do
			printf '%s' "$nameserver,"
		done | sed 's/.$/\n/' >> "$dnsconf"
	fi

	if [ -n "$librewolf_addons" ]; then
		librewolf='librewolf-bin'
		librewolfpath='/etc/skel/.librewolf'
		chmod -R 700 "$librewolfpath"
		chmod 755 "$librewolfpath"/defaultp.default/extensions
		chmod 600 "$librewolfpath"/defaultp.default/user.js
		# Calculate LibreWolf's about:config layout.css.devPixelsPerPx
		# 1680 x 1050 = 1764000, the base resolution which gets 1
		printf '%s\n' \
			"user_pref(\"layout.css.devPixelsPerPx\", \"$perpx\");" \
			>> /etc/skel/.librewolf/defaultp.default/user.js

		chmod 644 "$librewolfpath"/profiles.ini
		cd "$librewolfpath"/defaultp.default/extensions
		printf '%s\n' 'Downloading LibreWolf extensions...'
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

	sed_i 's/#ParallelDownloads = 5/ParallelDownloads = 4/' /etc/pacman.conf

	ln -fs /usr/share/zoneinfo/"$timezone" /etc/localtime

	[ -z "$hostname" ] && hostname='localhost.localdomain'
	printf '%s\n' "$hostname" > /etc/hostname
	hwclock --systohc
	sed_i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
	locale-gen

	printf '%s\n' 'LANG=en_US.UTF-8' > /etc/locale.conf
	gzip -d "$keymap".gz
	sed_i 's/1 = Escape/1 = Caps_Lock/' "$keymap"
	sed_i 's/58 = Caps_Lock/58 = Escape/' "$keymap"
	gzip "$keymap"
	printf '%s\n' "KEYMAP=$(basename "$keymap" | cut -d '.' -f 1)" \
		'FONT=ter-932n' > /etc/vconsole.conf

	ln -fs /bin/dash /bin/sh
	rm /etc/xdg/picom.conf

	printf '%s\n' root:"$rootpass" | chpasswd
	cat <<- EOF > /root/.bashrc
	# /root/.bashrc
	
	# Sometimes --reset-env is required, sometimes its absence is required
	alias yay='setpriv --reuid=bin --regid=bin --clear-groups --reset-env yay'
	alias makepkg='setpriv --reuid=bin --regid=bin --clear-groups makepkg'
	EOF

	# Build stuff as bin user, see /etc/doas.conf
	# and /var/builds/.config/yay/config.json
	usermod -c 'system build user' -d "$builddir" bin

	chown -R root:bin "$builddir"
	find "$builddir" -perm 644 -execdir chmod 664 {} +
	find "$builddir" -perm 755 -execdir chmod 775 {} +

	# Create a user for vm.sh to run QEMU
	useradd -c 'vm.sh user' -d "$vmdir" -p '!*' -r -s /usr/bin/nologin vm
	# If user backed up virtual machines, give correct perms for vm.sh
	chown -R root:vm "$vmdir"
	find "$vmdir" -type d -execdir chmod 770 {} + || chmod -R 770 "$vmdir"
	find "$vmdir" -type f -name '*.iso' -execdir chmod 440 {} +
	find "$vmdir" -type f \( -name drive -o -name drive2 \) \
		-execdir chmod 660 {} +

	for skeletons in documents downloads images .passwords; do
		mkdir /etc/skel/"$skeletons"
	done

	useradd -c "$usergecos" -G wheel,vm -m "$user"
	printf '%s\n' "$user:$userpass" | chpasswd
	[ -n "$librewolf_addons" ] && sed_i \
		"s/\/\/user_pref(\"browser.download.dir\", \"\/home\/NAME\/downloads\");/user_pref(\"browser.download.dir\", \"\/home\/$user\/downloads\");/" \
		/home/$user/.librewolf/defaultp.default/user.js

	pwck -s
	grpck -s

	# Accounts already locked
	getent shadow bin vm

	# Create temp sudo link to prevent asking for root password
	# since doas-sudo-shim has not been installed yet
	ln -s /usr/bin/doas /usr/local/bin/sudo
	cd "$builddir"/yay-bin && setpriv --reuid=bin --regid=bin \
		--clear-groups makepkg --noconfirm -ci
	rm /usr/local/bin/sudo
	# doas.conf only works when full pacman path is set with yay --save
	# also doas.conf must have full pacman path or else permission denied
	setpriv --reuid=bin --regid=bin --clear-groups --reset-env \
		yay --save --pacman /usr/bin/pacman
	setpriv --reuid=bin --regid=bin --clear-groups --reset-env \
		yay --removemake --noconfirm -S \
		devour $librewolf otf-san-francisco-mono doas-sudo-shim xbanish
	setpriv --reuid=bin --regid=bin --clear-groups \
		yay --removemake --noconfirm -S keynav
	
	# Calculate how large the XDM login box is
	if [ "$pixels" -gt 3200000 ]; then
		dpi=96
		increment=2048
		x=$((pixels - 3200000))
		y=$increment
		while [ "$x" -gt "$y" ]; do
			dpi=$((dpi + 1))
			x=$((x - y))
			y=$((y + increment))
		done
		sed_i "2a ! Dots per inch for the login box (higher=bigger)\nXft.dpi: $dpi\n" \
			/etc/X11/xdm/Xresources
	fi
	
	for srcdir in dwm dmenu st tabbed slock sfeed herbe; do
		cd "$builddir/$srcdir"
		patch -p 1 < "$builddir/$srcdir/$srcdir-archdesktop.diff"
	done
	# Calculate how big some suckless.org programs will be
	sed_i "s/monospace:size=10/SF Mono:size=$fontsize/g" "$builddir/dwm/config.def.h"
	sed_i "s/monospace:size=10/SF Mono:size=$fontsize/" "$builddir/dmenu/config.def.h"
	sed_i "s/Liberation Mono:pixelsize=12/SF Mono:pixelsize=$fontsize/" "$builddir/st/config.def.h"
	sed_i "s/monospace:size=9/SF Mono:size=$((fontsize * 3/4))/" "$builddir/tabbed/config.def.h"
	sed_i "s/monospace:size=10/SF Mono:size=$fontsize/" "$builddir/herbe/config.def.h"
	for srcdir in dwm dmenu st tabbed slock sfeed herbe; do
		cd "$builddir/$srcdir"
		make
		make install
	done

	if [ X"$bootmode" = X'efi' ]; then
		curl -Lo /boot/efi/shellx64.efi \
			'https://github.com/tianocore/edk2/raw/UDK2018/ShellBinPkg/UefiShell/X64/Shell.efi'
		efibootmgr -c -d /dev/"$disk" -p "$bootpart" -l '\shellx64.efi' \
			-L 'EFI Shell'
	fi

	# I think `uname -r' is unreliable, displays nonchroot kernel instead
	kver="$(find /usr/lib/modules/*/vmlinuz | cut -d / -f 5 | sort -u | tail -n 1)"
	cp /usr/lib/modules/"$kver"/vmlinuz /boot/linux
	printf '%s\n' 'compress="cat"' > /etc/dracut.conf
	[ X"$bootmode" = X'efi' ] && mkdir -p /boot/efi/EFI/Linux/
	if [ X"$bootloader" = X'limine' ]; then
		if [ X"$bootmode" = X'bios' ]; then
			cp /usr/share/limine/limine-bios.sys /boot
			limine bios-install /dev/"$disk"
		elif [ X"$bootmode" = X'efi' ]; then
			cp /usr/share/limine/BOOTX64.EFI \
				/boot/efi/EFI/Linux/BOOTX64.EFI
			efibootmgr -c -d /dev/"$disk" -p "$bootpart" \
				-l '\EFI\Linux\BOOTX64.EFI'
		fi
		cat <<- EOF > /boot/limine.cfg
		:Linux
			KERNEL_PATH=boot:///linux
			MODULE_PATH=boot:///initramfs.img
			CMDLINE=$kernelcmdline
			TERM_FONT_SCALE=2x2
			PROTOCOL=linux
		EOF
		main='/boot/initramfs.img'
		fallback='/boot/fallback.img'
	elif [ X"$bootloader" = X'efistub' ]; then
		printf '%s\n' "kernel_cmdline=\"$kernelcmdline\"" \
			> /etc/dracut.conf
		printf '%s\n' 'uefi="yes"' \
			'uefi_splash_image="/usr/share/systemd/bootctl/linux.bmp"' \
			>> /etc/dracut.conf
		efibootmgr -c -d /dev/"$disk" -p "$bootpart" \
			-l '\EFI\Linux\linux.efi'
		main='/boot/efi/EFI/Linux/linux.efi'
		fallback='/boot/efi/EFI/Linux/fallback.efi'
	fi
	dracut --hostonly --kver "$kver" "$main"
	dracut --kver "$kver" "$fallback"
	cat <<- EOF > /etc/pacman.d/hooks/20-initramfs.hook
	[Trigger]
	Type = Package
	Operation = Upgrade
	Target = linux*
	
	[Action]
	Description = Copying kernel to /boot and generating initramfs...
	When = PostTransaction
	Exec = /bin/sh -c "kver=\$(find /usr/lib/modules/*/vmlinuz | cut -d / -f 5 | sort -u | tail -n 1); cp /usr/lib/modules/"\$kver"/vmlinuz /boot/linux; dracut --force --kver=\$kver --hostonly $main; dracut --force --kver=\$kver $fallback"
	EOF

	mkdir -p /etc/systemd/system/tmp.mount.d
	cat <<- EOF > /etc/systemd/system/tmp.mount.d/override.conf
	[Mount]
	Options=mode=1777,strictatime,nosuid,nodev,size=50%%,nr_inodes=1m,noexec
	EOF

	systemctl enable NetworkManager.service gpm.service xdm.service

	clear
	printf '%s\n' 'Linux installation script completed.'
	if [ X"$bootmode" = X'efi' ] && [ X"$disklabel" != X'mbr' ]; then
		printf '%s\n' \
			'If your computer does not boot see TROUBLESHOOTING.md for (hopefully) easy fix!' \
			'<https://github.com/fkabell3/archdesktop/blob/main/TROUBLESHOOTING.md>'
	fi
	printf '%s\n' 'Now reboot and God bless!'
	exit 0
else
	printf '%s\n' "Syntax error: Usage: $0"
fi
