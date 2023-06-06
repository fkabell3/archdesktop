#!/bin/sh

dir=/var/vm
user=vm # Any non-root user with a shell
export user

# Find exit interface (default route with lowest metric),
# use /usr/bin/ip since ip -c interferes with grep -o
iface="$(/usr/bin/ip route show | grep "$(ip route show | grep default | \
	grep -o 'metric [0-9]*' | cut -d " " -f 2 | sort | head -n 1)" | \
	grep default | grep -o 'dev [a-z0-9]*' | cut -d " " -f 2)"

# If script fails, let the user hit Enter key before exiting so they
# have a chance to read error message(s) before terminal closes
# (for use with dmenu(1) graphical program)
delay="$2"
readexit() {
	[ X"$delay" = X"delay" ] && read REPLY
	exit "$1"
}
usage() {
	if [ "$(find $dir/* -type d 2>/dev/null | wc -l)" -gt 1 ]; then
		printf "%s" "Syntax error: Usage: $(basename $0) {"
		for vmdir in "$dir"/*; do
			[ -d "$vmdir" ] && printf "%s" \
				"$(basename "$vmdir") | "
		done | sed s/...$//
		printf "%s\n" "} [delay]"
	else
		printf "%s%s\n" "Syntax error: Usage: $(basename $0) " \
			"$(basename $(find "$dir"/* -type d)) [delay]"
	fi
	# Script exits with qemu-system-x86_64(1) exit code if that
	# executes so create an exit code which won't lead to ambiguity
	readexit 248
}
note() {
	printf "\t%s" ">> "
}
lsperm() {
	note
	ls -l "$1" | cut -d ' ' -f 1,3,4
}
rooterror() {
	[ X"$1" = X"fatal" ] && printf "%s" "Fatal: "
	printf "%s\n" "Run script non-root with sudo/doas/su -c"
}

if [ -n "$1" ] && [ -d "$dir/$1" ]; then
	vm="$dir/$1"
elif ! [ -d "$dir" ]; then
	printf "%s\n" "Fatal: $dir/ does not exist."
	readexit 249
elif [ -f "$dir/$1" ]; then
	printf "%s\n\t%s\n\t%s\n\t%s\n" \
		"Fatal: $dir/$1 is a file but should be a subdirectory which" \
			"1) must contain a file named \`drive', " \
			"2) likely should contain an .iso file," \
			"3) optionally contains a file named \`drive2'"
	readexit 250
elif find "$dir"/* -type d 2>/dev/null | grep . >/dev/null 2>&1; then
	usage
elif ! find "$dir/$1" >/dev/null 2>&1; then
	usage
else
	printf "%s\n" "Fatal: $dir/ has no subdirectories."
	readexit 251
fi

if ! [ X"$(whoami)" = X"root" ]; then
	rooterror fatal
       	readexit 252
fi

# Don't make the `-cdrom' argument crash qemu-system-x86_64(1).
# `-cdrom' with no extra argument will interpret the next line
# (such as `-drive') as an .iso file. If $_cdrom is blank,
# then so is $iso.
_cdrom=
if ! iso=$(ls "$vm"/*.iso 2>/dev/null); then
	printf "%s\n" "Warning: $vm/ has no .iso files"
	iso=
	export iso
else
	export iso
	r_iso="$(su -c -u $user \
		'[ -r "$iso" ] || printf "%s%s\n\t%s\n" "Warning: User $user " \
			"likely needs read permissions to" "$iso"')"
	if [ -n "$r_iso" ]; then
		printf "%s\n" "$r_iso"
		lsperm "$iso"
		iso=
	else
		_cdrom="-cdrom"
	fi

fi

drive="$vm/drive"
if [ -f "$drive" ]; then
	export drive
	rw_drive="$(su -c -u $user \
		'if ! [ -w "$drive" ] || ! [ -r "$drive" ]; then
			printf "%s%s\n\t%s\n" "Fatal: User $user needs read " \
				"and write permissions to" "$drive"
		fi')"
	if [ -n "$rw_drive" ] ; then
		printf "%s\n" "$rw_drive"
		lsperm "$drive"
		readexit 253
	fi
else
		printf "%s\n" "Fatal: $drive does not exist"
		readexit 254
fi

_drive=
drive2="$vm/drive2"
if [ -f "$drive2" ]; then
	export drive2
	rw_drive2="$(su -c -u $user \
		'if ! [ -w "$drive2" ] || ! [ -r "$drive" ]; then
			printf "%s%s\n\t%s\n" "Warning: User $user likely " \
				"needs read and write permissions to" "$drive2"
		fi')"
	if [ -n "$rw_drive2" ]; then
		printf "%s\n" "$rw_drive2"
		lsperm "$drive2"
	else
		_drive="-drive"
		drive2="file=$drive2,format=raw"
	fi
else
	drive2=
fi


printf "%s\n" "Initializing $1 virtual machine..."

printf "%s\n" "Configuring network"
# Disable VPN here
brctl addbr virbr0
ip addr flush dev virbr0
ip addr add 10.0.0.1/30 dev virbr0
ip -6 addr add fe80::1/64 dev virbr0
ip link set virbr0 up
if [ X"$(sysctl net.ipv4.ip_forward)" = X"net.ipv4.ip_forward = 0" ]; then
	sysctl net.ipv4.ip_forward=1 >/dev/null 2>&1
	routing4=wasoff
fi
if [ X"$(sysctl net.ipv6.conf.all.forwarding)" = \
	X"net.ipv6.conf.all.forwarding = 0" ]; then
	sysctl net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1
	routing6=wasoff
fi
iptables -t nat -A POSTROUTING -o "$iface" -j MASQUERADE

# Root has a hard time running GUI applications
export _drive drive2 _cdrom
su -c -u "$user" 'devour qemu-system-x86_64 \
	-enable-kvm \
	-m 8192 \
	-smp 12 \
	-display gtk,zoom-to-fit=on \
	-nic bridge,br=virbr0 \
	-drive file="$drive",format=raw \
	"$_drive" "$drive2" \
	"$_cdrom" "$iso"' \
       	>/dev/null 2>&1

status="$?"

case "$status" in
	# This condition (0) does not guarantee success
	0) printf "%s\n" "Virtual machine shutdown!";;
	139) printf "%s\n" "Fatal: Virtual Machine GUI failed!";;
	*) printf "%s\n" "Virtual machine failed!";;
esac

printf "%s\n" "Undoing network config changes"
# Re-enable VPN here
ip link set virbr0 down
brctl delbr virbr0
[ X"$routing4" = X"wasoff" ] && sysctl net.ipv4.ip_forward=0 >/dev/null 2>&1
[ X"$routing6" = X"wasoff" ] && sysctl net.ipv6.conf.all.forwarding=0 \
	>/dev/null 2>&1

case "$status" in
	0) exit "$status";;
	139) printf "%s\n" "Root likely not permitted by X access control list"
	note
	printf "%s\n" \
		"try executing \`xhost +local:' from the graphical user"
		rooterror;;
esac
readexit "$status"
