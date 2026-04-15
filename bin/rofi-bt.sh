#!/usr/bin/env bash
# Minimal bluetooth toggler via rofi. Lists paired devices and toggles
# connect/disconnect for the chosen one.

set -e

mapfile -t devices < <(bluetoothctl devices Paired | sed 's/^Device //')
if [ ${#devices[@]} -eq 0 ]; then
  notify-send "Bluetooth" "No paired devices"
  exit 0
fi

menu=""
for d in "${devices[@]}"; do
  mac=${d%% *}
  name=${d#* }
  if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
    menu+="● $name"$'\n'
  else
    menu+="○ $name"$'\n'
  fi
done

choice=$(printf '%s' "$menu" | rofi -dmenu -i -p "bluetooth")
[ -z "$choice" ] && exit 0

name=${choice#* }
mac=""
for d in "${devices[@]}"; do
  if [ "${d#* }" = "$name" ]; then
    mac=${d%% *}
    break
  fi
done
[ -z "$mac" ] && exit 0

if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
  bluetoothctl disconnect "$mac" >/dev/null && notify-send "Bluetooth" "Disconnected $name"
else
  bluetoothctl connect "$mac" >/dev/null && notify-send "Bluetooth" "Connected $name"
fi
