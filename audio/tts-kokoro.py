#!/usr/bin/env python
"""Kokoro-82M synth wrapper for speak-summary.sh (English).

Usage: tts-kokoro.py <voice> <out.wav> <text>

Voices: af_*/am_* are US, bf_*/bm_* are GB — the accent/lang is derived from
the name prefix, no extra argument needed. Engine lives in the ~/tts-kokoro
venv; model files (kokoro-v1.0.onnx + voices-v1.0.bin) in ~/tts-models/kokoro/
(override with KOKORO_MODEL_DIR).
"""
import os
import sys


def main():
    voice, out, text = sys.argv[1], sys.argv[2], sys.argv[3]
    import soundfile as sf
    from kokoro_onnx import Kokoro

    mdir = os.environ.get("KOKORO_MODEL_DIR",
                          os.path.expanduser("~/tts-models/kokoro"))
    kokoro = Kokoro(os.path.join(mdir, "kokoro-v1.0.onnx"),
                    os.path.join(mdir, "voices-v1.0.bin"))
    lang = "en-gb" if voice.startswith("b") else "en-us"
    samples, sr = kokoro.create(text, voice=voice, speed=1.0, lang=lang)
    sf.write(out, samples, sr)


if __name__ == "__main__":
    main()
