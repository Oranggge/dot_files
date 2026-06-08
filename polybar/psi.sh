#!/bin/sh
# Polybar PSI (Pressure Stall Information) module.
#
# Hidden when nothing is being stalled; shows the worst sustained pressure
# when work is actually being delayed. Uses the avg60 window (last minute).
#
# Severity priority: IO > MEM > CPU (matches typical desktop pain order).
#
#   /proc/pressure/io     full avg60 >= 10   → tasks stalled waiting on disk
#   /proc/pressure/memory full avg60 >=  5   → memory reclaim pressure
#   /proc/pressure/cpu    some avg60 >= 30   → CPU contention (no `full` for cpu)

ALERT='#fb4934'

full_avg60() {
    awk '/^full/ {for(i=2;i<=NF;i++) if($i ~ /^avg60=/){gsub("avg60=","",$i); print $i; exit}}' "$1"
}
some_avg60() {
    awk '/^some/ {for(i=2;i<=NF;i++) if($i ~ /^avg60=/){gsub("avg60=","",$i); print $i; exit}}' "$1"
}
above() { awk -v v="$1" -v t="$2" 'BEGIN{exit !(v+0 >= t+0)}'; }

io=$(full_avg60  /proc/pressure/io     2>/dev/null)
mem=$(full_avg60 /proc/pressure/memory 2>/dev/null)
cpu=$(some_avg60 /proc/pressure/cpu    2>/dev/null)

if   above "${io:-0}"  10; then printf '%%{F%s} io %.0f%%%%{F-}\n'  "$ALERT" "$io"
elif above "${mem:-0}"  5; then printf '%%{F%s}󰍛 mem %.0f%%%%{F-}\n' "$ALERT" "$mem"
elif above "${cpu:-0}" 30; then printf '%%{F%s} cpu %.0f%%%%{F-}\n' "$ALERT" "$cpu"
fi
