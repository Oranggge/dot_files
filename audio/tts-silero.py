#!/usr/bin/env python
"""Silero v5 synth wrapper for speak-summary.sh (Russian).

Usage: tts-silero.py <speaker> <out.wav> <text>

Speakers: aidar baya kseniya eugene xenia. Engine lives in the ~/tts-silero
venv (CPU-only torch); model at ~/tts-models/silero/v5_ru.pt (override with
SILERO_MODEL). v5 places word stress (ударение) and resolves homographs
automatically — the put_accent/put_yo kwargs are passed when the model still
accepts them, dropped when it does the work internally.
"""
import os
import sys


def main():
    speaker, out, text = sys.argv[1], sys.argv[2], sys.argv[3]
    import soundfile as sf
    import torch

    torch.set_num_threads(4)
    mpath = os.environ.get("SILERO_MODEL",
                           os.path.expanduser("~/tts-models/silero/v5_ru.pt"))
    model = torch.package.PackageImporter(mpath).load_pickle(
        "tts_models", "model")
    model.to(torch.device("cpu"))
    sr = 48000
    try:
        audio = model.apply_tts(text=text, speaker=speaker, sample_rate=sr,
                                put_accent=True, put_yo=True)
    except TypeError:
        audio = model.apply_tts(text=text, speaker=speaker, sample_rate=sr)
    sf.write(out, audio.numpy(), sr)


if __name__ == "__main__":
    main()
