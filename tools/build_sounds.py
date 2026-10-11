#!/usr/bin/env python3
"""Weapon sounds from The Free Firearm Sound Library (CC0, opengameart.org/content/the-free-firearm-sound-library).

python3 tools/build_sounds.py <path to 'Prepared SFX Library'>   ->  assets/sfx/<weapon>.wav, <weapon>_far.wav

Per gun, the near-distance recording (stereo) becomes the first-person shot: cut at the transient, a little
low-end weight and soft saturation for punch, a short sub thump, the room tail kept and faded. The mid-distance
recording becomes the shot other players hear (mono for 3D positioning, darker, longer tail).
"""
import os, sys, wave, json, hashlib
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'sfx')
RATE = 48000
# key: (near file, mid file, near seconds, far seconds, thump Hz, thump level)
GUNS = {
    'acr':    ('AR-15/D_32P.wav', 'AR-15/D_24P.wav', 1.7, 2.6, 58, .35),
    'ak':     ('AK-47/C_28P.wav', 'AK-47/C_31P.wav', 1.8, 2.8, 52, .45),
    'sniper': ('Tikka/W_29P.wav', 'Tikka/W_24P.wav', 2.6, 3.4, 45, .6),
    'pistol': ('Walther PPQ/X_39P.wav', 'Walther PPQ/X_31P.wav', 1.2, 2.0, 70, .25),
    'smg':    ('Carl Gustav M45/G_31P.wav', 'Carl Gustav M45/G_20P.wav', 1.3, 2.2, 65, .25),
}


def read(path):
    w = wave.open(path)
    n, ch, width, rate = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
    raw = np.frombuffer(w.readframes(n), np.uint8)
    if width == 3:
        b = raw.reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        v = np.where(v & 0x800000, v - 0x1000000, v).astype(np.float32) / 8388608.0
    else:
        v = np.frombuffer(raw.tobytes(), np.int16).astype(np.float32) / 32768.0
    return v.reshape(-1, ch), rate


def lowpass(x, cutoff, rate):
    """One-pole low-pass along axis 0 (cheap, smooth)."""
    a = np.exp(-2 * np.pi * cutoff / rate)
    y = np.empty_like(x); acc = np.zeros(x.shape[1:], np.float32)
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc; y[i] = acc
    return y


def resample(x, src, dst):
    if src == dst:
        return x
    # Anti-alias (windowed sinc) then linear interpolation to the new grid.
    taps = 63; fc = 0.45 * dst / src
    t = np.arange(taps) - taps // 2
    h = np.sinc(2 * fc * t) * np.hamming(taps); h /= h.sum()
    y = np.stack([np.convolve(x[:, c], h, mode='same') for c in range(x.shape[1])], 1)
    pos = np.arange(int(len(y) * dst / src)) * src / dst
    i = np.minimum(pos.astype(int), len(y) - 2); f = (pos - i)[:, None]
    return y[i] * (1 - f) + y[i + 1] * f


def cut(x, seconds):
    env = np.abs(x).max(1)
    onset = int(np.argmax(env > env.max() * 0.2))
    start = max(0, onset - int(0.003 * RATE))
    y = x[start:start + int(seconds * RATE)].copy()
    n = len(y); fade = np.ones(n, np.float32)
    k = int(n * 0.45); fade[n - k:] = np.linspace(1, 0, k) ** 2
    y *= fade[:, None]
    y[:int(0.002 * RATE)] *= np.linspace(0, 1, int(0.002 * RATE))[:, None]
    return y


def normalize(x, peak_db):
    return x * (10 ** (peak_db / 20) / max(np.abs(x).max(), 1e-6))


def write(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    w = wave.open(path, 'wb'); w.setnchannels(x.shape[1]); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes(pcm.tobytes()); w.close()


def world_near():
    """Mono positional copies of the included near shots; preserve the stereo local mix."""
    records = []
    for key in GUNS:
        source = os.path.join(OUT, key + '.wav')
        target = os.path.join(OUT, key + '_near.wav')
        x, rate = read(source)
        assert rate == RATE, (key, rate)
        write(target, normalize(x.mean(1, keepdims=True), -0.8))
        records.append({'source': key + '.wav', 'source_sha256': hashlib.sha256(open(source, 'rb').read()).hexdigest(),
                        'output': key + '_near.wav', 'output_sha256': hashlib.sha256(open(target, 'rb').read()).hexdigest(),
                        'channels': 1, 'sample_rate': RATE})
    with open(os.path.join(OUT, 'WORLD_NEAR_SOURCES.json'), 'w') as f:
        json.dump({'license': 'CC0-1.0', 'source_library': 'https://opengameart.org/content/the-free-firearm-sound-library',
                   'modification': 'Downmix the existing processed stereo shot to mono and normalize peak to -0.8 dBFS.',
                   'files': records}, f, indent=2)
        f.write('\n')


def main():
    lib = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for key, (near, mid, near_s, far_s, thump_hz, thump_lvl) in GUNS.items():
        x, rate = read(os.path.join(lib, near)); x = resample(x, rate, RATE)
        y = cut(x, near_s)
        body = lowpass(y, 180, RATE)
        y = y + body * 0.9                      # low-end weight
        y = np.tanh(normalize(y, 0) * 1.8) / np.tanh(1.8)   # soft saturation: punch
        t = np.arange(int(0.16 * RATE)) / RATE
        thump = np.sin(2 * np.pi * thump_hz * t * (1 - t * 1.5)) * np.exp(-t * 26) * thump_lvl
        y[:len(thump)] += thump[:, None]
        write(os.path.join(OUT, key + '.wav'), normalize(y, -0.8))
        x, rate = read(os.path.join(lib, mid)); x = resample(x, rate, RATE)
        f = cut(x, far_s).mean(1, keepdims=True)
        f = lowpass(f, 5200, RATE)
        write(os.path.join(OUT, key + '_far.wav'), normalize(f, -2.0))
        print('built', key)
    world_near()


if __name__ == '__main__':
    world_near() if '--world-near-only' in sys.argv else main()
