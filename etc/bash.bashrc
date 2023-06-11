# /etc/bash.bashrc

case "$-" in
	*i*);;
	*) return;;
esac

[ -f "$HOME"/.bashrc ] && . "$HOME"/.bashrc

alias ls="ls -F --color=auto"
alias ll="ls -hl"
alias grep="grep --color=auto"
alias which="which 2>/dev/null"
alias ip="ip -c"

PS1='[\u@\h \w]\$ '
EDITOR=/bin/vim
PAGER=/bin/less
SYSTEMD_PAGER=
export EDITOR PAGER SYSTEMD_PAGER

_ps() {
	case "$1" in
		cpu|pcpu|"") ps axo pid,command,pcpu,pmem --sort=pcpu;;
		mem|pmem) ps axo pid,command,pcpu,pmem --sort=pmem;;
		*) ps "$@";;
	# Hide kernel processes
	esac | grep -Fv "["
}
