# Synthesizes the small original sound effects in audio/sfx/ (22.05 kHz mono WAV).
import numpy as np, wave, os
SR = 22050
rng = np.random.default_rng(7)
def env(n, a=0.005, r=None):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4))
    r = r or (n / SR)
    return e * np.exp(-t / (r / 4))
def tone(f0, f1, dur, wave_="sine"):
    n = int(SR * dur); f = np.linspace(f0, f1, n); ph = 2 * np.pi * np.cumsum(f) / SR
    if wave_ == "square": return np.sign(np.sin(ph)) * 0.6
    if wave_ == "tri": return 2 / np.pi * np.arcsin(np.sin(ph))
    return np.sin(ph)
def noise(dur, lp=1.0):
    n = int(SR * dur); x = rng.uniform(-1, 1, n)
    if lp < 1.0:
        y = np.zeros(n); a = lp
        for i in range(1, n): y[i] = y[i - 1] + a * (x[i] - y[i - 1])
        x = y / (np.max(np.abs(y)) + 1e-9)
    return x
def save(name, x, vol=0.7):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    d = (x * 32767).astype(np.int16)
    with wave.open(f"audio/sfx/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())
def cat(*xs): return np.concatenate(xs)
os.makedirs("audio/sfx", exist_ok=True)
x = tone(1400, 500, 0.09, "tri"); save("shoot", x * env(len(x), 0.002, 0.09), 0.45)
x = noise(0.08, 0.3) * 0.7 + tone(180, 90, 0.08); save("hit", x * env(len(x), 0.001, 0.08), 0.5)
x = noise(0.25, 0.08) * np.sin(np.linspace(0, np.pi, int(SR * 0.25))) + 0.3 * tone(300, 900, 0.25); save("cast", x, 0.4)
x = noise(0.7, 0.05) + 0.6 * tone(90, 35, 0.7); save("boom", x * env(len(x), 0.002, 0.7), 0.75)
x = tone(900, 1600, 0.18, "tri") + 0.5 * tone(1350, 2400, 0.18); save("snare", x * env(len(x), 0.002, 0.18), 0.4)
x = tone(700, 200, 0.14, "square") * 0.5 + noise(0.14, 0.2) * 0.3; save("tower", x * env(len(x), 0.002, 0.14), 0.4)
x = cat(tone(1318, 1318, 0.06), tone(1975, 1975, 0.14)); save("coin", x * env(len(x), 0.002, 0.2), 0.35)
x = cat(*[tone(f, f, 0.08, "tri") for f in (523, 659, 784, 1046)]); save("levelup", x * env(len(x), 0.002, 0.5), 0.45)
x = tone(400, 80, 0.45, "tri") + noise(0.45, 0.1) * 0.3; save("death", x * env(len(x), 0.002, 0.45), 0.5)
x = cat(*[tone(f, f * 1.01, 0.1) for f in (660, 880, 1100)]); save("heal", x * env(len(x), 0.01, 0.4), 0.4)
x = tone(900, 700, 0.04, "tri"); save("click", x * env(len(x), 0.001, 0.04), 0.35)
x = cat(*[tone(f, f, d, "tri") for f, d in ((523, .14), (659, .14), (784, .14), (1046, .5))]); save("victory", x * env(len(x), 0.005, 1.2), 0.5)
x = cat(*[tone(f, f, d, "tri") for f, d in ((440, .2), (370, .2), (311, .2), (262, .6))]); save("defeat", x * env(len(x), 0.005, 1.4), 0.5)
print("sfx done")
