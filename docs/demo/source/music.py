"""Soundtrack for the README video: 22 s at 120 BPM (beat 0.5 s, bar 2 s), A minor.

Everything (drums, bass, chords, arpeggio and the effects on clicks and cuts) sits on one
beat grid counted from the first frame. Writes a 48 kHz stereo WAV.
Usage: python3 music.py out.wav
"""
import sys
import wave

import numpy as np

SR = 48000
DUR = 22.0
BEAT = 0.5
N = int(SR * DUR)
t_all = np.arange(N) / SR
L = np.zeros(N)
R = np.zeros(N)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def place(sig, start, gain=1.0, pan=0.0):
    i = int(round(start * SR))
    if i >= N:
        return
    sig = sig[: N - i]
    L[i : i + len(sig)] += sig * gain * np.sqrt(0.5 * (1 - pan))
    R[i : i + len(sig)] += sig * gain * np.sqrt(0.5 * (1 + pan))


def env(n, a=0.005, d=0.3, curve=4.0):
    t = np.arange(n) / SR
    att = np.clip(t / a, 0, 1) if a > 0 else 1
    return att * np.exp(-curve * t / d)


def kick():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t * 30)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9)


rng = np.random.default_rng(7)


def noise(n):
    return rng.standard_normal(n)


def hat(open_=False):
    n = int((0.18 if open_ else 0.05) * SR)
    x = np.diff(noise(n + 1))  # crude high-pass
    return x * env(n, 0.001, 0.12 if open_ else 0.03, 3)


def clap():
    n = int(0.2 * SR)
    x = noise(n)
    x = np.convolve(x, np.ones(6) / 6, mode="same") - np.convolve(x, np.ones(40) / 40, mode="same")
    e = env(n, 0.002, 0.12, 4)
    for k in (0.008, 0.016):
        e += 0.5 * np.roll(env(n, 0.002, 0.03, 4), int(k * SR))
    return x * e


def saw(freq, n, detune=0.0):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for d in (-detune, 0, detune):
        out += 2 * ((t * freq * (1 + d)) % 1) - 1
    return out / 3


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lp_fast(x, cutoff, passes=2):
    # One-pole low-pass via scipy-free IIR using cumulative trick on blocks.
    a = np.exp(-2 * np.pi * cutoff / SR)
    for _ in range(passes):
        y = np.empty_like(x)
        acc = 0.0
        # vectorise in chunks for speed
        for s in range(0, len(x), 4096):
            seg = x[s : s + 4096]
            out = np.empty_like(seg)
            for i, v in enumerate(seg):
                acc = (1 - a) * v + a * acc
                out[i] = acc
            y[s : s + 4096] = out
        x = y
    return x


def pluck(freq, dur=0.22):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(4 * np.pi * freq * t) + 0.12 * np.sin(6 * np.pi * freq * t)
    return x * env(n, 0.003, dur, 5)


def bell(freq, dur=1.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t * 4) + 0.2 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t * 8)
    return x * env(n, 0.002, dur, 4)


def pad(notes, dur):
    n = int(dur * SR)
    x = sum(saw(midi(m), n, 0.004) for m in notes) / len(notes)
    x = lp_fast(x, 1400, 1)
    t = np.arange(n) / SR
    a = np.clip(t / 0.25, 0, 1) * np.clip((dur - t) / 0.3, 0, 1)
    return x * a


def tick():
    n = int(0.03 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * 2200 * t) * np.exp(-t * 180)


def whoosh(length=0.5):
    n = int(length * SR)
    x = lp_fast(noise(n), 2500, 1)
    t = np.arange(n) / SR
    return x * (t / length) ** 2


# Chords, one per bar: Am – F – C – G (A minor → C major lift).
CHORDS = [[57, 60, 64], [53, 57, 60], [48, 52, 55, 60], [55, 59, 62]]
BASS = [45, 41, 36, 43]

bars = int(DUR / 2)
for b in range(bars):
    start = b * 2.0
    chord = CHORDS[b % 4]
    # Intro (0–4.5 s): pad and ticking hats only. Groove from the click at 4.5 s.
    pad_gain = 0.42 if start < 4 else 0.30
    if start < 20:
        place(pad(chord, 2.0), start, pad_gain, -0.2)
        place(pad([n + 12 for n in chord], 2.0), start, pad_gain * 0.5, 0.25)

for i in range(int(DUR / BEAT)):
    tb = i * BEAT
    if tb < 4.5:
        # 16th ticks building tension
        for k in range(4):
            place(hat(), tb + k * BEAT / 4, 0.06 + 0.08 * tb / 4.5, 0.3)
        continue
    if tb >= 20.0:
        continue
    place(kick(), tb, 0.55)
    if i % 2 == 1:
        place(clap(), tb, 0.22, 0.1)
    place(hat(), tb + BEAT / 2, 0.09, 0.35)
    place(hat(open_=(i % 4 == 3)), tb + BEAT * 0.75, 0.04, -0.3)
    # bass: root on the beat and an octave on the off-beat
    bar = int(tb // 2)
    root = BASS[bar % 4]
    place(lowpass(saw(midi(root), int(0.22 * SR)), 600) * env(int(0.22 * SR), 0.004, 0.25, 3), tb, 0.38)
    place(lowpass(saw(midi(root + 12), int(0.18 * SR)), 900) * env(int(0.18 * SR), 0.004, 0.2, 3), tb + BEAT / 2, 0.22)

# Arpeggio in 8ths from the reveal, through the outro.
for i in range(int(4.5 / 0.25), int(20 / 0.25)):
    tb = i * 0.25
    chord = CHORDS[int(tb // 2) % 4]
    notes = chord + [chord[0] + 12]
    place(pluck(midi(notes[i % len(notes)] + 12)), tb, 0.16, 0.4 if i % 2 else -0.4)

# Outro: a C major bell chord on the downbeat of the last bars, ringing out.
for k, m in enumerate([72, 76, 79, 84]):
    place(bell(midi(m), 3.5), 18.0 + k * 0.125, 0.2, -0.3 + 0.2 * k)
place(pad([48, 55, 60, 64], 4.0), 18.0, 0.4)
place(kick(), 18.0, 0.5)

# Effects, in key and on the grid.
for c in (4.0, 4.5, 6.0, 9.0, 9.5, 13.0, 14.0):
    place(tick(), c, 0.18, 0.5)
for c in (4.5, 17.0):  # lock closes: A–E chime
    place(bell(midi(81), 1.2), c, 0.12, 0.3)
    place(bell(midi(88), 1.2), c + 0.125, 0.08, 0.5)
for c in (3.0, 7.5, 12.0, 16.0, 18.0):
    place(whoosh(0.5), c - 0.5, 0.05)
for k in range(6):  # typing in the terminal, on 16ths
    place(tick(), 16.25 + k * 0.125, 0.06, -0.5)

# Master: gentle fade, soft clip, normalise.
fade = np.clip((DUR - t_all) / 1.5, 0, 1)
mix = np.stack([L, R]) * fade
mix = np.tanh(mix * 1.2) / np.tanh(1.2)
mix = mix / np.max(np.abs(mix)) * 0.89
pcm = (mix.T * 32767).astype("<i2")
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("wrote", sys.argv[1])
