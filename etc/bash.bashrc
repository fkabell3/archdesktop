# /etc/bash.bashrc

case "$-" in
	*i*);;
	*) return;;
esac

PS1='[\u@\h \w]\$ '
EDITOR=/bin/vim
PAGER=/bin/less
SYSTEMD_PAGER=
export EDITOR PAGER SYSTEMD_PAGER

alias ls='ls -F --color=auto'
alias ll='ls -hl'
alias grep='grep --color=auto'
alias which='which 2>/dev/null'
alias ip='ip -c'
alias copy='xclip -selection clipboard'
alias paste='xclip -o -selection clipboard'

#set -o vi

# Combine history across TTYs
#PROMPT_COMMAND='history -a; history -c; history -r'
HISTCONTROL=ignoredups:erasedups

_ps() {
	case "$1" in
		cpu|pcpu|'')
			ps axo pid,command,pcpu,pmem --sort=pcpu
		;;
		mem|pmem)
			ps axo pid,command,pcpu,pmem --sort=pmem
		;;
		*)
			ps "$@"
		;;
	# Hide kernel processes
	esac | grep -Fv \[
}

[ -f "$HOME"/.bashrc ] && . "$HOME"/.bashrc
