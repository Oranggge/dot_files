#!/usr/bin/env bash
# Two-step rofi picker for PipeWire default devices.
# Step 1: Output or Input. Step 2: pick a device.
# Sets the default sink/source AND moves existing streams over, so the
# switch is immediate (not just for newly-started apps).
#
# Wired to click-left on the polybar pulseaudio module. Mirrors rofi-bt.sh.

set -e

rofi_menu() { rofi -dmenu -i -p "$1"; }

# pick_device <sink|source>
pick_device() {
  local kind=$1 default get_default set_default move list_streams stream_ids
  if [ "$kind" = sink ]; then
    get_default="get-default-sink"; set_default="set-default-sink"
    list_streams="short sink-inputs"; move="move-sink-input"
  else
    get_default="get-default-source"; set_default="set-default-source"
    list_streams="short source-outputs"; move="move-source-output"
  fi

  default=$(pactl $get_default)

  # Names and descriptions, index-aligned. Skip .monitor sources.
  mapfile -t names < <(pactl list short "${kind}s" | cut -f2 | grep -v '\.monitor$')
  declare -A descof
  while IFS=$'\t' read -r n d; do descof[$n]=$d; done < <(
    pactl list "${kind}s" \
      | awk -F': ' '/^\tName:/{n=$2} /^\tDescription:/{print n"\t"$2}'
  )

  local labels=() menu=""
  for n in "${names[@]}"; do
    local label="${descof[$n]:-$n}"
    [ "$n" = "$default" ] && label="$label ✓"
    labels+=("$label")
    menu+="$label"$'\n'
  done

  local choice
  choice=$(printf '%s' "$menu" | rofi_menu "$kind")
  [ -z "$choice" ] && exit 0

  # Map the chosen label back to its device name (first match handles dups).
  local i target=""
  for i in "${!labels[@]}"; do
    if [ "${labels[$i]}" = "$choice" ]; then target=${names[$i]}; break; fi
  done
  [ -z "$target" ] && exit 0

  pactl "$set_default" "$target"
  while read -r id; do
    [ -n "$id" ] && pactl "$move" "$id" "$target" 2>/dev/null || true
  done < <(pactl list $list_streams | cut -f1)

  local friendly=output; [ "$kind" = source ] && friendly=input
  notify-send "Audio" "Default $friendly → ${descof[$target]:-$target}"
}

step1=$(printf ' Output\n Input\n Mixer\n' | rofi_menu "audio")
case "$step1" in
  *Output) pick_device sink ;;
  *Input)  pick_device source ;;
  *Mixer)  pavucontrol & ;;
  *) exit 0 ;;
esac
