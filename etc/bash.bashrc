# /etc/bash.bashrc

case "$-" in
	*i*);;
	*) return;;
esac

alias ls='ls -F --color=auto'
alias ll="ls -hl"
alias grep='grep --color=auto'
alias ip='ip -c'

_ps() {
	case "$1" in
		cpu|pcpu|"") ps axo pid,command,pcpu,pmem --sort=pcpu;;
		mem|pmem) ps axo pid,command,pcpu,pmem --sort=pmem;;
		*) ps "$@";;
	# Hide kernel processes
	esac | grep -Fv "["
}

PS1='[\u@\h \w]\$ '
EDITOR=/bin/vim
PAGER=/bin/less
SYSTEMD_PAGER=
export EDITOR PAGER SYSTEMD_PAGER
