#!/bin/sh
# Polybar disk module — used % on /.
# Yellow >=70%, red >=90%. Use /usr/bin/df to bypass the duf alias.

FG='#ebdbb2'
PRIMARY='#fabd2f'
ALERT='#fb4934'

pct=$(/usr/bin/df --output=pcent / 2>/dev/null | tail -1 | tr -dc '0-9')
[ -z "$pct" ] && exit 0

color=$FG
if   [ "$pct" -ge 90 ]; then color=$ALERT
elif [ "$pct" -ge 70 ]; then color=$PRIMARY
fi

printf '%%{F%s}󰋊 %d%%%%{F-}\n' "$color" "$pct"
