# Audio Notes

## USB Microphone (MUSIC-BOOST MB-306)

Side-address USB condenser, USB 1.1 / 12 Mbps, Generalplus chip (`1b3f:0004`).
Lands as ALSA card `2`, source name
`alsa_input.usb-MUSIC-BOOST_USB_Microphone_MB-306-00.mono-fallback`.

### Where to plug it

Either works:
- **Direct to laptop USB-A** — simplest, always works.
- **ThinkPad USB-C Dock, port at USB path `3-3.1.3.4`** — empirically verified to
  capture clean voice at full scale even through both VIA Labs internal hubs.

Earlier we tested port `3-3.1.3.2` (same hub depth) and it produced only flat
noise. The difference between the two ports was **not** topology — it was likely
the mic's touch-mute button being pressed during the failing tests, or a flaky
cable. The "cascaded VIA hub TT eats USB 1.1 audio packets" theory was wrong:
once the mute issue was ruled out, depth-4 ports work fine.

If a future port-probe is needed: `bash /tmp/dock-port-test.sh "label"` (the
script can be recreated from this repo's git log — see commit that adds this
README).

### Mic gain (`amixer -c 2 set Mic <pct>%`)

Currently set to **73% (+21 dB)** — the `amixer set 75%` step quantizes to 22/30.
Rationale:
- ALSA range is 0–30 steps, default is 30/30 = 100% / +33 dB.
- Tried 33% (+3 dB) and 50% (+10.5 dB) first. Both produced clean audio on
  close-talk tests, but in real use with **openwhispr (Groq Whisper backend)**
  for dictation, normal speaking-voice peaks landed at only ~19% full scale
  and average voice RMS sat at ~1000 — only ~3.7× above the ~270 RMS room
  ambient (fan, AC, keyboard). That SNR is below what Whisper's VAD needs to
  fire reliably, so detection worked maybe every second utterance.
- Bumping to 73% pushed the absolute level above Whisper's VAD floor and
  detection rate improved. SNR didn't change (gain raises signal and noise
  equally) — what changed is that the absolute dBFS threshold the VAD checks
  is now being cleared.
- Going higher (85–100%) is fine if needed; the cost is occasional clipping
  on loud bursts (laugh, cough). Whisper handles a clipped syllable here and
  there.

Adjust if:
- **Dictation still misses words when you talk normally** → bump to 85%
  (`amixer -c 2 set Mic 85%`), then 100% if still spotty. Also consider
  lowering openwhispr's own VAD / silence threshold setting — that's the
  cleaner fix (raises sensitivity without raising noise floor).
- **You hear distortion / "krrtt" / square-wave artifacts** → drop to 50%.
- **Other side on calls says you're too loud / distorted** → drop to 50%.

**Real SNR fix (not just absolute level):** distance matters far more than
gain. Halving the distance to the mic = 4× louder voice with the same room
ambient = real SNR improvement. If openwhispr is missing words and bumping
gain isn't enough, move the mic closer rather than going past 80%.

The change is not persisted across reboot. Re-apply by hand, or wire a one-shot
systemd-user unit if it starts being a pain.

### Mute button

The red ring/LED on the mic body is a real hardware mute — it gates capture to
zero at the ALSA level. If apps report "stream open" while you're muted, that's
expected (the device handle stays open; only the samples are zero).

### Trivia

The laptop's built-in mics (`HiFi__Mic1__source` / `HiFi__Mic2__source`) are
substantially weaker than this USB mic — normal speech registers at ~1% full
scale on the built-in vs ~100% on the USB. Default source should stay on the
USB mic when it's connected; PipeWire's auto-selection does this correctly.

### Default source / output

- Default source is set by PipeWire's policy — usually picks the highest-priority
  connected mic, so the USB mic wins automatically over the laptop's built-ins.
- Default sink under normal docked use is `Lenovo ThinkPad USB-C Dock Audio
  Analog Stereo`. Override with
  `pactl set-default-sink <name>` / `pactl set-default-source <name>`.

### Pavucontrol "breaks audio when opened"

Noticed and investigated but **not** reproduced as a real fault. The PipeWire
event log shows no mute / no volume change / no default-device switch when
pavucontrol opens — only peak-meter subscriptions on every sink and source. The
brief perception of audio dropping is likely either (a) AnyDesk's forwarded
audio stuttering during the subscription burst when running remotely, or
(b) the dock card's combined `output:analog-stereo+input:mono-fallback` profile
re-evaluating ports. If it becomes a real annoyance, switch the dock to
output-only profile:
```
pactl set-card-profile alsa_card.usb-Lenovo_ThinkPad_USB-C_Dock_Audio_000000000000-00 \
  output:analog-stereo
```
(Reversible — flip back to `output:analog-stereo+input:mono-fallback`.)
