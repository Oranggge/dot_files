#!/usr/bin/env bash
# Show a headphones glyph in polybar when the Pixel Buds Pro are connected.
# Prints nothing otherwise. Glyph is nf-fa-headphones (U+F025).

MAC="AC:3E:B1:84:79:45"

if bluetoothctl info "$MAC" 2>/dev/null | grep -q "Connected: yes"; then
  printf '\uf025\n'
else
  printf '\n'
fi
