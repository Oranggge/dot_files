#!/bin/sh
# Polybar RAM module — working-set used %.
#
# Computed as (MemTotal - MemAvailable) / MemTotal, i.e. RAM actually held by
# applications. Excludes buff/cache (which Linux happily reclaims), so the
# number reflects real memory pressure instead of "Linux uses 80% of RAM all
# the time because of caches". Pair this with `psi` — psi fires when reclaim
# is actually stalling tasks; this one is the ambient gauge.
#
# Foreground <70, yellow 70-85, red >=85.

FG='#ebdbb2'
PRIMARY='#fabd2f'
ALERT='#fb4934'

total=$(awk '/^MemTotal:/     {print $2; exit}' /proc/meminfo)
avail=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)
[ -z "$total" ] || [ -z "$avail" ] && exit 0

awk -v t="$total" -v a="$avail" -v fg="$FG" -v p="$PRIMARY" -v alert="$ALERT" 'BEGIN{
    pct = (t - a) * 100 / t
    color = fg
    if      (pct >= 85) color = alert
    else if (pct >= 70) color = p
    printf "%%{F%s}󰍛 %.0f%%%%{F-}\n", color, pct
}'
