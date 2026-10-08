#!/usr/bin/env python3
"""Spirebreak match BGM ("Spire Rush") - original chiptune-phonk loop, synthesized in numpy.

Original composition by DJ for Tomoki R. Style inspiration: hard phonk (STAKILLAZ-like energy:
808 slides, cowbell riffs, punchy kick/clap, dark minor key). No melody, riff, bassline, hook or
lyric from any existing song is used; every note below was written for this track.

Writes _render_3x.f32 (stereo float32 @44.1 kHz): the 56-bar loop rendered 3x back to back plus a
4 s tail, so the render script can master it continuously and keep pass 2 (seamless loop).
"""
import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
BPM = 150
STEP = 4410                 # one 16th note at 150 BPM (exact)
BAR = 16 * STEP             # 70,560 samples
BARS = 56
N = BARS * BAR              # 3,951,360 samples = 89.6 s
PASSES = 3
TOTAL = PASSES * N + 4 * SR
rng = np.random.default_rng(7)

def mtof(m): return 440.0 * 2 ** ((m - 69) / 12.0)

# ------------------------------------------------------------------ oscillators
def _blep(t, dt):
    out = np.zeros_like(t)
    m = t < dt; x = t[m] / dt[m]; out[m] = x + x - x * x - 1
    m = t > 1 - dt; x = (t[m] - 1) / dt[m]; out[m] = x * x + x + x + 1
    return out

def pulse(freq, duty):
    dt = freq / SR
    ph = np.cumsum(dt) % 1.0
    y = np.where(ph < duty, 1.0, -1.0)
    return y + _blep(ph, dt) - _blep((ph - duty) % 1.0, dt)

def tri4(freq):            # NES-style 4-bit stepped triangle
    ph = np.cumsum(freq / SR) % 1.0
    t = 1 - 4 * np.abs(ph - 0.5)
    return np.round(t * 7.5) / 7.5

def sine(freq):
    return np.sin(2 * np.pi * np.cumsum(freq / SR))

def _lfsr(short):
    reg, n = 1, (93 if short else 32767)
    out = np.empty(n)
    tap = 6 if short else 1
    for i in range(n):
        bit = (reg ^ (reg >> tap)) & 1
        reg = (reg >> 1) | (bit << 14)
        out[i] = (reg & 1) * 2.0 - 1.0
    return out
LONG, SHORT = _lfsr(False), _lfsr(True)

def noise(n, clock, short=False):
    seq = SHORT if short else LONG
    start = rng.integers(len(seq))
    idx = (start + (np.arange(n) * clock / SR).astype(np.int64)) % len(seq)
    return seq[idx]

def freq_curve(n, m, slide_from=None, slide_s=0.06, vib=0.0, vib_delay=0.15, vib_rate=5.5):
    f = np.full(n, float(mtof(m)))
    if slide_from is not None:
        k = min(n, int(slide_s * SR))
        f0, f1 = mtof(slide_from), mtof(m)
        f[:k] = f0 * (f1 / f0) ** (np.linspace(0, 1, k) ** 0.7)
    if vib:
        t = np.arange(n) / SR
        depth = np.clip((t - vib_delay) / 0.2, 0, 1) * vib
        f *= 2 ** (depth * np.sin(2 * np.pi * vib_rate * t) / 12)
    return f

def env(n, gate, a=0.003, d=0.08, s=0.7, r=0.04):
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-6), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-6)))
    g = gate / SR
    rel = t > g
    if rel.any():
        eg = e[np.argmax(rel)] if rel.any() else s
        e[rel] = eg * np.exp(-(t[rel] - g) / r)
    return e

# ------------------------------------------------------------------ buses / event placing
BUSES = {k: np.zeros(TOTAL) for k in
         ['kick', 'clap', 'hat', 'snare', 'crash', 'tom', 'bass', 'bell', 'bell_lp', 'lead',
          'counter', 'arp', 'pad', 'riser']}

def place(bus, pos, sig):
    pos = int(round(pos))
    if pos >= TOTAL: return
    sig = sig[:TOTAL - pos]
    BUSES[bus][pos:pos + len(sig)] += sig

def S(bar, step): return bar * BAR + step * STEP          # bar is 0-based within a pass

# ------------------------------------------------------------------ instruments
def kick(p, v=1.0):
    n = int(0.42 * SR); t = np.arange(n) / SR
    f = 52 + 170 * np.exp(-t / 0.028)
    body = np.tanh(2.2 * sine(f) * np.exp(-t / 0.14))
    click = noise(n, 22000) * np.exp(-t / 0.004) * 0.35
    place('kick', p, v * (body + click))

def clap(p, v=1.0):
    n = int(0.3 * SR); t = np.arange(n) / SR
    e = np.exp(-t / 0.075)
    for o in (0.0, 0.009, 0.018):
        e = np.maximum(e, (t >= o) * np.exp(-np.clip(t - o, 0, None) / 0.006))
    place('clap', p, v * noise(n, 18000) * e)

def hat(p, v=1.0, open_=False):
    n = int((0.35 if open_ else 0.06) * SR); t = np.arange(n) / SR
    place('hat', p, v * noise(n, 30000, short=True) * np.exp(-t / (0.11 if open_ else 0.018)))

def snare(p, v=1.0):
    n = int(0.22 * SR); t = np.arange(n) / SR
    body = tri4(190 * np.exp(-t / 0.05) + 140) * np.exp(-t / 0.05) * 0.6
    place('snare', p, v * (noise(n, 16000) * np.exp(-t / 0.07) + body))

def crash(p, v=1.0):
    n = int(1.6 * SR); t = np.arange(n) / SR
    place('crash', p, v * noise(n, 40000) * np.exp(-t / 0.5))

def tom(p, hz, v=1.0):
    n = int(0.25 * SR); t = np.arange(n) / SR
    f = hz * (1 + 0.8 * np.exp(-t / 0.03))
    place('tom', p, v * (tri4(f) * np.exp(-t / 0.12) + 0.25 * noise(n, 8000) * np.exp(-t / 0.01)))

def bass(p, m, steps, v=1.0, slide_from=None):
    gate = steps * STEP - 200; n = gate + int(0.06 * SR)
    f = freq_curve(n, m, slide_from, slide_s=0.07)
    e = env(n, gate, a=0.002, d=0.5, s=0.55, r=0.025)
    sig = 0.8 * tri4(f) + 0.45 * sine(f / 2)
    place('bass', p, v * np.tanh(1.8 * sig * e))

def bell(p, m, steps=2, v=1.0, bus='bell'):          # 808-style cowbell from two pulse waves
    n = int(max(steps * STEP, 0.25 * SR)); t = np.arange(n) / SR
    f = mtof(m)
    sig = pulse(np.full(n, f), 0.5) + 0.8 * pulse(np.full(n, f * 1.48), 0.5)
    e = 0.45 * np.exp(-t / 0.13) + 0.55 * np.exp(-t / 0.018)
    e *= np.clip((steps * STEP + 0.06 * SR - t * SR) / (0.03 * SR), 0, 1)   # choke at note end
    place(bus, p, v * sig * e)

def lead(p, m, steps, v=1.0, slide_from=None, duty=0.25, bus='lead', vib=0.22):
    gate = steps * STEP - 300; n = gate + int(0.08 * SR)
    f = freq_curve(n, m, slide_from, slide_s=0.05, vib=vib)
    place(bus, p, v * pulse(f, duty) * env(n, gate, a=0.004, d=0.12, s=0.72, r=0.035))

def arp_note(p, m, v=1.0):
    n = int(STEP * 0.5); t = np.arange(n) / SR
    place('arp', p, v * pulse(np.full(n, mtof(m)), 0.125) * np.exp(-t / 0.04))

def pad(p, m, steps, v=1.0):
    gate = steps * STEP; n = gate + int(0.3 * SR)
    f = freq_curve(n, m, vib=0.12, vib_delay=0.3, vib_rate=4.5)
    place('pad', p, v * pulse(f, 0.5) * env(n, gate, a=0.35, d=0.5, s=0.85, r=0.25))

def riser(p, steps, v=1.0):
    n = steps * STEP; t = np.linspace(0, 1, n)
    f = 180 * (8 ** (t ** 1.6))
    sig = 0.5 * pulse(f, 0.125) + 0.6 * noise(n, 6000 + 24000 * t)
    place('riser', p, v * sig * (t ** 2))

# ------------------------------------------------------------------ harmony / composition
FM, DB, C, EB, BBM = 'Fm', 'Db', 'C', 'Eb', 'Bbm'
ROOT = {FM: 41, DB: 37, C: 36, EB: 39, BBM: 34}                   # bass octave
TONES = {FM: [77, 80, 84], DB: [73, 77, 80], C: [72, 76, 79], EB: [75, 79, 82], BBM: [82, 85, 89]}
A_PROG = [FM, FM, DB, C]
B_PROG = [DB, EB, FM, FM, BBM, C, DB, C]
BD_PROG = [FM, FM, DB, DB, BBM, BBM, C, C]

SECTIONS = ([('A', c) for c in A_PROG * 2] + [('A2', c) for c in A_PROG * 2] +
            [('B', c) for c in B_PROG] + [('A3', c) for c in A_PROG * 2] +
            [('BD', c) for c in BD_PROG] + [('BUILD', c) for c in A_PROG] +
            [('CLIMAX', c) for c in B_PROG] + [('TURN', c) for c in A_PROG])
assert len(SECTIONS) == BARS

# Cowbell riff (4 bars, original). (step, midi, len)
RIFF = [[(0, 77, 2), (3, 77, 2), (6, 80, 2), (8, 84, 2), (10, 82, 1), (11, 80, 2), (14, 78, 2)],
        [(0, 77, 2), (3, 77, 2), (6, 80, 2), (8, 87, 2), (10, 85, 2), (12, 84, 2), (14, 80, 2)],
        [(0, 77, 2), (3, 77, 2), (6, 80, 2), (8, 85, 2), (10, 84, 1), (11, 80, 2), (14, 77, 2)],
        [(0, 76, 2), (3, 76, 2), (6, 79, 2), (8, 84, 2), (10, 82, 2), (12, 79, 2), (14, 76, 2)]]

# A2 counter-line (50% pulse, long tones), per 4 bars: (step-in-4-bars, midi, len)
COUNTER = [(0, 84, 16), (16, 87, 8), (24, 85, 8), (32, 89, 16), (48, 88, 8), (56, 91, 8)]

# B lead melody, 8 bars (step within 8 bars, midi, len, slide_from)
B_LEAD = [(0, 80, 4, None), (4, 77, 2, None), (6, 80, 2, None), (8, 82, 4, None), (12, 84, 4, None),
          (16, 82, 6, None), (22, 79, 2, None), (24, 87, 8, 84),
          (32, 84, 4, None), (36, 80, 4, None), (40, 77, 4, None), (44, 79, 2, None), (46, 80, 2, None),
          (48, 84, 12, 82), (60, 82, 2, None), (62, 80, 2, None),
          (64, 85, 4, None), (68, 84, 2, None), (70, 82, 2, None), (72, 77, 4, None), (76, 82, 4, None),
          (80, 84, 6, None), (86, 82, 2, None), (88, 79, 4, None), (92, 76, 4, None),
          (96, 77, 4, None), (100, 80, 4, None), (104, 85, 4, None), (108, 89, 4, None),
          (112, 88, 8, 91), (120, 84, 4, None), (124, 79, 4, None)]
# Climax: same first half, new second half that climbs higher
CLIMAX_LEAD = B_LEAD[:16] + [
          (64, 89, 4, None), (68, 87, 2, None), (70, 85, 2, None), (72, 84, 4, None), (76, 85, 4, None),
          (80, 88, 4, None), (84, 91, 4, 88), (88, 88, 8, None),
          (96, 89, 6, None), (102, 87, 2, None), (104, 85, 4, None), (108, 84, 4, None),
          (112, 84, 12, 86), (124, 79, 2, None), (126, 76, 2, None)]

def chord_bell_bar(p, chord, odd, v):
    r, t3, t5 = TONES[chord]
    rhythm = [0, 3, 6, 8, 10, 11, 14]
    notes = [r, r, t3, t5, r + 12, t5, t3] if odd else [r, r, t3, t5, t3, r, t5 - 12]
    for s, m in zip(rhythm, notes):
        bell(p + s * STEP, m, 2 if s != 10 else 1, v)

def compose(off):
    for b, (sec, ch) in enumerate(SECTIONS):
        P = off + b * BAR
        root = ROOT[ch]
        nxt = SECTIONS[(b + 1) % BARS]
        bar_in4 = b % 4
        # ---------------- drums
        if sec in ('A', 'A2', 'A3', 'B', 'CLIMAX', 'TURN'):
            kicks = [0, 6, 10] + ([14] if bar_in4 in (1, 3) else [])
            if sec == 'CLIMAX': kicks = [0, 3, 6, 10, 12] if b % 2 else [0, 6, 10, 14]
            if sec == 'TURN' and b == BARS - 1: kicks = [0, 6]
            for s in kicks: kick(P + s * STEP, 1.0 if s in (0, 6) else 0.85)
            for s in (4, 12): clap(P + s * STEP)
            if sec == 'A3':               # triplet hats for variety (phonk roll feel)
                for k in range(12): hat(P + k * 4 * STEP / 3, 0.75 if k % 3 == 0 else 0.5)
            elif sec in ('B', 'CLIMAX'):
                for s in range(16): hat(P + s * STEP, (0.8 if s % 2 else 0.45), open_=(sec == 'CLIMAX' and s % 4 == 2))
            else:
                for s in range(0, 16, 2): hat(P + s * STEP, 0.8 if s % 4 == 2 else 0.5)
            if bar_in4 == 3 and not (sec == 'TURN' and b == BARS - 1):   # 1/24 hat roll on beat 4
                for k in range(6): hat(P + 12 * STEP + k * 4 * STEP / 6, 0.4 + 0.08 * k)
            if bar_in4 == 0 and (b % 8 == 0 or sec in ('CLIMAX',)): crash(P, 0.9)
        elif sec == 'BD':
            clap(P + 8 * STEP, 0.8)
            for s in range(0, 16, 4): hat(P + (s + 2) * STEP, 0.4)
            if b >= 36:
                kick(P, 0.9); kick(P + 10 * STEP, 0.7)
            if b == 32: crash(P, 0.6)
        elif sec == 'BUILD':
            k = b - 40
            if k < 3:
                for s in range(0, 16, 4): kick(P + s * STEP, 0.95)
            else:
                for s in (0, 4, 8): kick(P + s * STEP, 0.95)
            div = [4, 2, 1, 0.5][k]
            s = 0.0
            while s < (16 if k < 3 else 12):
                snare(P + s * STEP, 0.35 + 0.12 * k + 0.25 * s / 16); s += div
            for s in range(2, 16, 4): hat(P + s * STEP, 0.5)
            if k == 0: riser(P, 60, 0.9)
        # tom fill at the very end -> back to bar 1
        if b == BARS - 1:
            for i, hz in enumerate([262, 233, 196, 175, 147, 131, 110, 98]):
                tom(P + (8 + i) * STEP, hz, 0.9)
            snare(P + 15 * STEP, 0.7); snare(P + 15.5 * STEP, 0.8)
        # ---------------- bass (808)
        if sec in ('A', 'A2', 'A3', 'B', 'CLIMAX', 'TURN'):
            bass(P, root, 6)
            bass(P + 6 * STEP, root, 4)
            bass(P + 10 * STEP, root + 12, 3, 0.9, slide_from=root)
            if sec == 'TURN' and b == BARS - 1:
                bass(P + 13 * STEP, root, 3, 0.8, slide_from=root + 12)
            elif bar_in4 == 3 or sec in ('A3', 'CLIMAX'):
                tgt = ROOT[nxt[1]]
                bass(P + 13 * STEP, root, 2, 0.85, slide_from=root + 12)
                bass(P + 15 * STEP, tgt + 7, 1, 0.8, slide_from=root)
            else:
                bass(P + 13 * STEP, root, 3, 0.85, slide_from=root + 12)
        elif sec == 'BD':
            if b % 2 == 0:
                prev = ROOT[SECTIONS[b - 1][1]]
                bass(P, root, 30, 0.95, slide_from=prev if prev != root else None)
        elif sec == 'BUILD':
            for s in range(0, 16, 2): bass(P + s * STEP, root + (12 if s % 4 == 2 else 0), 2, 0.85)
        # ---------------- cowbell riff
        if sec in ('A', 'A2', 'A3', 'TURN'):
            for s, m, ln in RIFF[bar_in4]: bell(P + s * STEP, m, ln, 1.0)
        elif sec == 'BUILD':
            for s, m, ln in RIFF[bar_in4]: bell(P + s * STEP, m, ln, 0.55 + 0.15 * (b - 40))
        elif sec == 'CLIMAX':
            chord_bell_bar(P, ch, b % 2 == 0, 0.9)
        elif sec == 'BD':
            if b < 36:
                for s, m, ln in RIFF[0][:2]: bell(P + s * STEP, m, ln, 0.7)
            else:
                for s, m, ln in RIFF[bar_in4]: bell(P + s * STEP, m, ln, 0.9, bus='bell_lp')
        # ---------------- counter-line (A2) & A3 low pulse double
        if sec == 'A2' and bar_in4 == 0:
            for s, m, ln in COUNTER: lead(P + s * STEP, m, ln, 0.8, duty=0.5, bus='counter', vib=0.15)
        if sec == 'A3':
            for s, m, ln in RIFF[bar_in4]: lead(P + s * STEP, m - 12, ln, 0.55, duty=0.25, bus='counter', vib=0)
        # ---------------- lead
        if sec in ('B', 'CLIMAX') and b in (16, 44):
            mel = B_LEAD if sec == 'B' else CLIMAX_LEAD
            for s, m, ln, sl in mel: lead(P + s * STEP, m, ln, 1.0, slide_from=sl)
        # ---------------- arps
        if sec in ('B', 'A3', 'CLIMAX', 'BUILD'):
            r, t3, t5 = TONES[ch]
            seq = [r, t3, t5, r + 12] if sec != 'BUILD' else [r - 12 + 12 * ((b - 40)), t3 - 12 + 12 * (b - 40), t5 - 12 + 12 * (b - 40)]
            for k in range(32):
                arp_note(P + k * STEP / 2, seq[k % len(seq)] - (12 if sec != 'BUILD' else 0) + 12, 0.8)
        # ---------------- pad (breakdown)
        if sec == 'BD' and b % 2 == 0:
            for m in TONES[ch]: pad(P, m - 12, 32, 0.5)

for i in range(PASSES):
    compose(i * N)

# ------------------------------------------------------------------ bus processing
def bp(x, lo=None, hi=None, order=2):
    if lo and hi: sos = butter(order, [lo, hi], 'bandpass', fs=SR, output='sos')
    elif lo: sos = butter(order, lo, 'highpass', fs=SR, output='sos')
    else: sos = butter(order, hi, 'lowpass', fs=SR, output='sos')
    return sosfilt(sos, x)

def _wet(x, D, g):
    # y[n] = x[n-D] + g*y[n-D]
    y = np.zeros(len(x))
    for k in range(D, len(x), D):
        e = min(k + D, len(x))
        y[k:e] = x[k - D:e - D] + g * y[k - D:e - D]
    return y

def reverb(x):
    out = np.zeros_like(x)
    for D, g in ((1557, 0.78), (1617, 0.77), (1491, 0.79), (1422, 0.8)):
        out += _wet(x, D, g)
    out *= 0.25
    for D, g in ((225, 0.5), (556, 0.5)):
        w = _wet(out, D, g)
        out = -g * out + w * (1 - g * g) / 1.0
    return out

B = BUSES
B['bell'] = bp(B['bell'], 450, 7000)
B['bell_lp'] = bp(bp(B['bell_lp'], 450, 1400), hi=1600)
B['bass'] = bp(np.tanh(1.3 * B['bass']), hi=5000)
B['clap'] = bp(B['clap'], 800, 6500)
B['hat'] = bp(B['hat'], lo=6000)
B['crash'] = bp(B['crash'], lo=4500)
B['snare'] = bp(B['snare'], 180, 8000)
B['pad'] = bp(B['pad'], hi=1800)
B['riser'] = bp(B['riser'], lo=300)
B['kick'] = np.tanh(1.2 * B['kick'])

GAIN = dict(kick=0.95, clap=0.42, hat=0.12, snare=0.33, crash=0.10, tom=0.45, bass=0.62,
            bell=0.36, bell_lp=0.38, lead=0.20, counter=0.12, arp=0.065, pad=0.06, riser=0.10)
PAN = dict(kick=0, clap=0, hat=0.25, snare=0, crash=-0.2, tom=0.1, bass=0, bell=-0.15, bell_lp=-0.15,
           lead=0.05, counter=-0.3, arp=0.35, pad=0, riser=0)

L = np.zeros(TOTAL); R = np.zeros(TOTAL)
send = np.zeros(TOTAL)
for k, x in B.items():
    x = x * GAIN[k]
    pl, pr = np.sqrt(0.5 * (1 - PAN[k])), np.sqrt(0.5 * (1 + PAN[k]))
    L += x * pl * 1.414; R += x * pr * 1.414
    send += x * {'bell': 0.25, 'bell_lp': 0.5, 'lead': 0.35, 'counter': 0.4, 'arp': 0.3, 'pad': 0.6,
                 'clap': 0.15, 'snare': 0.2, 'tom': 0.2}.get(k, 0)

# chip-style echoes: lead (dotted 8th) ping-ponged, cowbell (1/8) quietly
d3 = 3 * STEP
echo_lead = _wet(B['lead'] * GAIN['lead'] + B['counter'] * GAIN['counter'], d3, 0.35) * 0.35
echo_bell = _wet(B['bell'] * GAIN['bell'] + B['bell_lp'] * GAIN['bell_lp'], 2 * STEP, 0.3) * 0.22
L += 0.4 * echo_lead + 0.9 * echo_bell
R += 0.9 * echo_lead + 0.4 * echo_bell
rv = reverb(bp(send, 300, 6000))
L += 0.22 * rv; R += 0.22 * np.roll(rv, 331)

out = np.stack([L, R], axis=1).astype(np.float32)
out.tofile('_render_3x.f32')
print('rendered', out.shape, 'peak', float(np.abs(out).max()), 'N', N)
