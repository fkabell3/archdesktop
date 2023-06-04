#!/bin/sh

raw=$(mktemp /tmp/strawinput.XXXXXX)
trimmed=$(mktemp /tmp/sttrimmedinput.XXXXXX)

grep -Eo '/[^ ]*'\|'(http|https)://[a-zA-Z0-9./?=_%:+-]*[.][a-z]*[/]?[a-zA-Z0-9./?=_%:+-\&]*' | sort | uniq > "$raw"
# Change :+-]*' | sort
#     to :+-\&]*' | sort
# in order to allow query strings in the URL

while read line; do
	if [ -f "$line" ] || printf "%s" "$line" | grep 'http'; then
		printf "%s\n" "$line" >> "$trimmed"
	fi
done < "$raw"

selection=$(dmenu -l 10 -w "$WINDOWID" < "$trimmed")

case "$selection" in
	"");;
	http*) $BROWSER "$selection";;
	*) if [ -f "$selection" ]; then
		st -e vim "$selection"
	fi;;
esac
