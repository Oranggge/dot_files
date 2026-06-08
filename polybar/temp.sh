#!/bin/sh
# Polybar CPU temperature module.
# Reads x86_pkg_temp (Intel package temp). Yellow >=75°C, red >=85°C.

FG='#ebdbb2'
PRIMARY='#fabd2f'
ALERT='#fb4934'

zone=""
for d in /sys/class/thermal/thermal_zone*; do
    t=$(cat "$d/type" 2>/dev/null) || continue
    case "$t" in
        x86_pkg_temp|coretemp) zone="$d"; break ;;
    esac
done
# Fallback: TCPU on systems without x86_pkg_temp exposed
if [ -z "$zone" ]; then
    for d in /sys/class/thermal/thermal_zone*; do
        t=$(cat "$d/type" 2>/dev/null) || continue
        [ "$t" = "TCPU" ] && zone="$d" && break
    done
fi
[ -z "$zone" ] && exit 0

milli=$(cat "$zone/temp" 2>/dev/null) || exit 0
temp=$((milli / 1000))

color=$FG
if   [ "$temp" -ge 85 ]; then color=$ALERT
elif [ "$temp" -ge 75 ]; then color=$PRIMARY
fi

printf '%%{F%s} %d°%%{F-}\n' "$color" "$temp"
