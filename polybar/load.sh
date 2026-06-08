#!/bin/sh
# Polybar load module — load5 / nproc ratio.
# >1.0 means real CPU overcommit (sustained); below that, ambient feedback only.

FG='#ebdbb2'
PRIMARY='#fabd2f'
ALERT='#fb4934'

cores=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo)
load5=$(awk '{print $2}' /proc/loadavg)

awk -v l="$load5" -v c="$cores" -v fg="$FG" -v p="$PRIMARY" -v a="$ALERT" 'BEGIN{
    r = l / c
    color = fg
    if (r >= 1.0)      color = a
    else if (r >= 0.7) color = p
    printf "%%{F%s}󰓅 %.2f%%{F-}\n", color, r
}'
