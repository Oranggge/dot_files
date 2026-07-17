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
#
# The io branch is gated on real device activity (see io_is_real below).
# /proc/pressure/io alone cannot be trusted: the kernel can leak nr_iowait and
# pin `io full avg60` near 50% indefinitely while every device is idle, no task
# is in D state and both queues are empty — a stuck counter, not a stall.
# Diagnosed 2026-07-17 after three days of a permanently red bar. Believing PSI
# on its own is exactly the crying-wolf failure this module was built to avoid,
# so io pressure now has to be corroborated by /proc/diskstats.

ALERT='#fb4934'

# Minimum device utilisation (%) over the sampling window for io pressure to be
# believed. A genuine io stall always keeps some queue non-empty, so real
# pressure sits far above this; the phantom sits at ~0.
MIN_BUSY_PCT=5

STATE="${XDG_RUNTIME_DIR:-/tmp}/polybar-psi.busy"

full_avg60() {
    awk '/^full/ {for(i=2;i<=NF;i++) if($i ~ /^avg60=/){gsub("avg60=","",$i); print $i; exit}}' "$1"
}
some_avg60() {
    awk '/^some/ {for(i=2;i<=NF;i++) if($i ~ /^avg60=/){gsub("avg60=","",$i); print $i; exit}}' "$1"
}
above() { awk -v v="$1" -v t="$2" 'BEGIN{exit !(v+0 >= t+0)}'; }

# Sum of "ms spent doing I/O" (field 13 of /proc/diskstats) across whole block
# devices. Partitions are skipped — they have no /sys/block entry of their own.
# zram is deliberately included: swap decompression stalls are real stalls.
device_busy_ms() {
    sum=0
    while read -r _ _ name _ _ _ _ _ _ _ _ _ busy _; do
        [ -d "/sys/block/$name" ] || continue
        sum=$((sum + busy))
    done < /proc/diskstats
    echo "$sum"
}

# Was any device actually busy since the last tick? Returns 0 (true) only on
# positive evidence — an unreadable/absent/rolled-over state file means "unknown",
# which suppresses io rather than risking a false alert. Self-corrects next tick.
# Uses /proc/uptime (monotonic) so a wall-clock jump can't skew the window.
io_is_real() {
    now_cs=$(awk '{printf "%d", $1*100}' /proc/uptime)
    now_busy=$(device_busy_ms)
    real=1

    if [ -r "$STATE" ]; then
        read -r prev_cs prev_busy < "$STATE"
        d_cs=$((now_cs - ${prev_cs:-0}))
        d_busy=$((now_busy - ${prev_busy:-0}))
        # d_busy < 0 means a device went away or counters reset; treat as unknown.
        if [ "$d_cs" -gt 0 ] && [ "$d_busy" -ge 0 ]; then
            [ $((d_busy * 10 / d_cs)) -ge "$MIN_BUSY_PCT" ] && real=0
        fi
    fi

    printf '%s %s\n' "$now_cs" "$now_busy" > "$STATE" 2>/dev/null
    return $real
}

io=$(full_avg60  /proc/pressure/io     2>/dev/null)
mem=$(full_avg60 /proc/pressure/memory 2>/dev/null)
cpu=$(some_avg60 /proc/pressure/cpu    2>/dev/null)

# Sampled unconditionally: the delta window has to stay fresh even while io is
# quiet, or the first tick after a spike would average over a stale gap.
io_is_real; io_real=$?

if   above "${io:-0}"  10 && [ "$io_real" -eq 0 ]; then
    printf '%%{F%s} io %.0f%%%%{F-}\n'  "$ALERT" "$io"
elif above "${mem:-0}"  5; then printf '%%{F%s}󰍛 mem %.0f%%%%{F-}\n' "$ALERT" "$mem"
elif above "${cpu:-0}" 30; then printf '%%{F%s} cpu %.0f%%%%{F-}\n' "$ALERT" "$cpu"
fi
