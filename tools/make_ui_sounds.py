#!/usr/bin/env python3
"""Menu sounds (original, CC0): a soft tick on hover, a muted mechanical click on select.
python3 tools/make_ui_sounds.py  ->  assets/sfx/ui_hover.wav, ui_click.wav"""
import os, wave
import numpy as np
RATE = 48000
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'sfx')

def write(name, x):
    x = x / max(np.abs(x).max(), 1e-6) * 0.5
    w = wave.open(os.path.join(OUT, name), 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes((x * 32767).astype('<i2').tobytes()); w.close()

rng = np.random.default_rng(3)
t = np.arange(int(0.05 * RATE)) / RATE
hover = np.sin(2 * np.pi * 2400 * t) * np.exp(-t * 140) * 0.6 + rng.normal(0, 1, len(t)) * np.exp(-t * 400) * 0.15
write('ui_hover.wav', hover)
t = np.arange(int(0.12 * RATE)) / RATE
click = (np.sin(2 * np.pi * 900 * t) * np.exp(-t * 60) + np.sin(2 * np.pi * 180 * t) * np.exp(-t * 35) * 0.8
         + rng.normal(0, 1, len(t)) * np.exp(-t * 220) * 0.35)
write('ui_click.wav', click)
print('ui sounds written')
