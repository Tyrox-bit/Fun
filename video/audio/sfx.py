"""Procedural sound design for the 72h blackout short. numpy only.
Reads timeline (exported from src/timeline.js) and writes out/sfx_mix.wav (stereo 48k)."""
import json, sys, wave
import numpy as np

SR = 48000
rng = np.random.default_rng(72)


def T(d):
    return np.arange(int(d * SR)) / SR


def noise(d):
    return rng.standard_normal(int(d * SR))


def band(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    m = np.clip((f - lo * 0.8) / (lo * 0.2 + 1e-9), 0, 1) * np.clip((hi * 1.25 - f) / (hi * 0.25), 0, 1)
    return np.fft.irfft(X * m, len(x))


def lp(x, fc):
    return band(x, 0.1, fc)


def hp(x, fc):
    return band(x, fc, SR / 2.2)


def norm(x, peak=1.0):
    m = np.max(np.abs(x)) + 1e-12
    return x / m * peak


def env_ad(n, a, d, curve=4.0):
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-6), np.exp(-(t - a) / max(d, 1e-6) * curve / 4))
    return e


def sweep(f0, f1, d, kind='exp', wave_='sin'):
    t = T(d)
    if kind == 'exp':
        f = f0 * (f1 / f0) ** (t / d)
    else:
        f = f0 + (f1 - f0) * t / d
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave_ == 'sin':
        return np.sin(ph)
    if wave_ == 'saw':
        return sum(np.sin(k * ph) / k for k in range(1, 8))
    if wave_ == 'sq':
        return sum(np.sin(k * ph) / k for k in range(1, 12, 2))
    return np.sin(ph)


def tone(f, d, wave_='sin'):
    return sweep(f, f, d, 'lin', wave_)


def reverb(x, dur=1.2, mix=0.25, damp=3000):
    ir = noise(dur) * np.exp(-np.arange(int(dur * SR)) / SR * 5.5 / dur)
    ir = lp(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    n = len(x) + len(ir)
    wet = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)
    out = np.zeros(n)
    out[:len(x)] += x * (1 - mix)
    out += wet * mix * 1.4
    return out


def pad(x, d):
    n = int(d * SR)
    return x[:n] if len(x) >= n else np.concatenate([x, np.zeros(n - len(x))])


# ------------------------------------------------------------------ sounds (mono unless tuple)
def s_whoosh(soft=False):
    d = 0.75 if soft else 0.5
    t = T(d)
    peak = 0.17 if not soft else 0.3
    e = np.exp(-((t - peak) / (0.08 if not soft else 0.16)) ** 2 * 1.0)
    e = np.where(t < peak, (t / peak) ** 2, np.exp(-(t - peak) * (9 if not soft else 5)))
    x = np.zeros(len(t))
    bands = [(150, 500), (400, 1200), (900, 2500), (2000, 6000)]
    nz = noise(d)
    for i, (lo, hi) in enumerate(bands):
        c = (i + 0.5) / len(bands)
        w = np.exp(-((t / d - c * 0.55 - 0.05) / 0.18) ** 2)
        x += band(nz, lo, hi) * w * (1.0 if i < 2 else 0.6)
    x = x * e
    if soft:
        x = lp(x, 2500)
    x = norm(x)
    pan = np.clip((t / d) * 1.6 - 0.3, 0, 1)
    return (x * (1 - pan * 0.7), x * (0.3 + pan * 0.7))


def s_swipe():
    d = 0.28
    t = T(d)
    nz = noise(d)
    x = band(nz, 1500, 7000) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 2
    x += band(nz, 400, 1500) * 0.5 * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 3
    x = norm(x)
    pan = t / d
    return (x * (1.2 - pan), x * (0.2 + pan))


def s_riser(d):
    t = T(d)
    nz = noise(d)
    x = np.zeros(len(t))
    for i, (lo, hi) in enumerate([(300, 800), (700, 1800), (1500, 4000), (3500, 9000)]):
        w = np.clip((t / d) * 4 - i, 0, 1)
        x += band(nz, lo, hi) * w
    x = norm(x) * 0.6 + norm(sweep(180, 900, d, 'exp', 'saw')) * 0.35
    e = (t / d) ** 2.2
    e[-int(0.015 * SR):] *= np.linspace(1, 0, int(0.015 * SR))
    return norm(x * e)


def s_clack():
    x = np.zeros(int(0.5 * SR))
    for k, (tt, a) in enumerate([(0.0, 1.0), (0.018, 0.6), (0.032, 0.35)]):
        n = int(tt * SR)
        c = hp(noise(0.03), 1800) * env_ad(int(0.03 * SR), 0.0005, 0.008)
        x[n:n + len(c)] += c * a
    th = tone(85, 0.25) * env_ad(int(0.25 * SR), 0.002, 0.07)
    x[:len(th)] += th * 0.9
    return norm(reverb(x, 0.9, 0.25))


def s_powerdown():
    d = 1.5
    t = T(d)
    x = sweep(700, 32, d, 'exp', 'saw') * np.exp(-t * 1.6)
    hum = (np.sin(2 * np.pi * 50 * t) + 0.5 * np.sin(2 * np.pi * 100 * t) + 0.25 * np.sin(2 * np.pi * 150 * t)) * np.exp(-t * 3)
    x = lp(x, 3000) + 0.6 * hum
    return norm(x)


def s_boom():
    d = 1.8
    t = T(d)
    x = sweep(75, 28, d, 'exp') * np.exp(-t * 2.3)
    x += lp(noise(d), 300) * np.exp(-t * 9) * 0.6
    c = hp(noise(d), 2000) * np.exp(-t * 80) * 0.3
    return norm(reverb(np.tanh((x + c) * 1.6), 1.5, 0.3, 1200))


def s_impact():
    d = 1.4
    t = T(d)
    sub = sweep(90, 38, d, 'exp') * np.exp(-t * 3.2)
    mid = band(noise(d), 120, 1500) * np.exp(-t * 14)
    top = hp(noise(d), 3000) * np.exp(-t * 45) * 0.5
    x = np.tanh((sub * 1.2 + mid * 0.7 + top) * 1.8)
    return norm(reverb(x, 1.6, 0.35, 2500))


def s_subdrop():
    d = 1.6
    t = T(d)
    x = sweep(110, 24, d, 'exp') * np.minimum(1, t * 30) * np.exp(-t * 1.4)
    return norm(np.tanh(x * 1.5))


def s_glitch():
    d = 0.35
    n = int(d * SR)
    x = np.zeros(n)
    i = 0
    while i < n:
        L = int(rng.uniform(0.008, 0.03) * SR)
        kind = rng.integers(0, 3)
        seg = min(L, n - i)
        tt = np.arange(seg) / SR
        if kind == 0:
            s = np.sign(np.sin(2 * np.pi * rng.uniform(80, 1800) * tt))
        elif kind == 1:
            s = np.round(rng.standard_normal(seg) * 3) / 3
        else:
            s = np.zeros(seg)
        x[i:i + seg] = s * rng.uniform(0.3, 1)
        i += seg
    return norm(band(x, 60, 9000))


def s_pop():
    d = 0.12
    t = T(d)
    x = sweep(900, 250, d, 'exp') * np.exp(-t * 40)
    x[:int(0.002 * SR)] += hp(noise(0.002), 3000)
    return norm(x)


def s_tickroll():
    d = 0.6
    x = np.zeros(int(d * SR))
    times = [0.5 * (1 - (1 - k / 13) ** 1.6) for k in range(14)]
    for k, tt in enumerate(times):
        n = int(tt * SR)
        c = (hp(noise(0.012), 2500) * 0.6 + tone(2600 + 60 * k, 0.012)) * env_ad(int(0.012 * SR), 0.0003, 0.004)
        x[n:n + len(c)] += c
    n = int(0.52 * SR)
    ding = (tone(1760, 0.3) + 0.5 * tone(2637, 0.3)) * env_ad(int(0.3 * SR), 0.001, 0.08)
    x[n:n + len(ding)] += ding[:len(x) - n] * 0.6
    return norm(x)


def s_zap():
    d = 0.3
    t = T(d)
    mod = (np.sin(2 * np.pi * 120 * t) > 0).astype(float)
    x = band(noise(d), 1500, 7000) * (0.4 + 0.6 * mod) * np.exp(-t * 9)
    x += np.sign(np.sin(2 * np.pi * 60 * t)) * 0.2 * np.exp(-t * 12)
    return norm(x)


def s_honk(f1=410, f2=515, d=0.5):
    t = T(d)
    x = tone(f1, d, 'sq') + tone(f2, d, 'sq')
    e = np.minimum(1, t * 60) * np.minimum(1, (d - t) * 40)
    return norm(reverb(lp(x, 2500) * e, 1.0, 0.25))


def s_clunk():
    d = 1.0
    t = T(d)
    x = sweep(90, 45, d, 'exp') * np.exp(-t * 8)
    for f, a, k in [(183, 0.6, 6), (433, 0.4, 9), (911, 0.3, 12), (1433, 0.25, 15), (2210, 0.15, 20)]:
        x += np.sin(2 * np.pi * f * t) * a * np.exp(-t * k)
    x += hp(noise(d), 1000) * np.exp(-t * 30) * 0.5
    r = np.zeros(len(t))
    for k in range(6):
        n = int((0.12 + k * 0.05 + rng.uniform(0, 0.02)) * SR)
        c = hp(noise(0.02), 1500) * env_ad(int(0.02 * SR), 0.0005, 0.006) * (0.4 / (k + 1))
        r[n:n + len(c)] += c
    return norm(reverb(np.tanh((x + r) * 1.4), 1.6, 0.35, 2000))


def s_click():
    x = np.zeros(int(0.06 * SR))
    for tt, a in [(0, 1), (0.025, 0.5)]:
        n = int(tt * SR)
        c = hp(noise(0.004), 2500) * env_ad(int(0.004 * SR), 0.0002, 0.001)
        x[n:n + len(c)] += c * a
    return norm(x)


def s_beep(f=1250, d=0.09):
    t = T(d)
    return norm(np.sin(2 * np.pi * f * t) * np.minimum(1, t * 400) * np.minimum(1, (d - t) * 200))


def s_batterylow():
    x = np.concatenate([s_beep(988, 0.12), np.zeros(int(0.05 * SR)), s_beep(784, 0.12), np.zeros(int(0.05 * SR)), s_beep(523, 0.25)])
    return norm(x)


def s_stamp():
    d = 0.9
    t = T(d)
    x = sweep(120, 50, d, 'exp') * np.exp(-t * 10)
    x += band(noise(d), 200, 3000) * np.exp(-t * 35) * 0.9
    x += hp(noise(d), 4000) * np.exp(-t * 90) * 0.4
    return norm(reverb(np.tanh(x * 2.0), 0.8, 0.2))


def s_error():
    x = np.concatenate([tone(160, 0.14, 'sq'), np.zeros(int(0.06 * SR)), tone(160, 0.22, 'sq')])
    t = np.arange(len(x)) / SR
    return norm(lp(x, 2200) * np.minimum(1, t * 200))


def s_cash():
    d = 0.9
    x = np.zeros(int(d * SR))
    for k in range(7):
        n = int(rng.uniform(0, 0.35) * SR)
        f0 = rng.uniform(2500, 4800)
        tt = T(0.4)
        c = sum(np.sin(2 * np.pi * f0 * r * tt) * a for r, a in [(1, 1), (1.47, 0.6), (2.09, 0.4), (2.73, 0.25)]) * np.exp(-tt * 14)
        x[n:n + len(c)] += c[:len(x) - n] * rng.uniform(0.4, 1)
    return norm(reverb(x, 0.6, 0.2, 6000))


def s_scan():
    d = 1.1
    t = T(d)
    x = sweep(300, 2400, d, 'exp') * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t))
    x += sweep(600, 4800, d, 'exp') * 0.25
    e = np.minimum(1, t * 10) * np.minimum(1, (d - t) * 6)
    return norm(reverb(x * e, 1.0, 0.3))


def s_gurgle(d):
    t = T(d)
    x = band(noise(d), 120, 900) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 3.3 * t)))
    for k in range(int(d * 14)):
        n = int(rng.uniform(0, d - 0.08) * SR)
        f = rng.uniform(180, 520)
        c = sweep(f, f * 2.2, 0.07, 'exp') * env_ad(int(0.07 * SR), 0.004, 0.02)
        x[n:n + len(c)] += c * rng.uniform(0.6, 1.4)
    e = np.minimum(1, t * 6) * np.minimum(1, (d - t) * 3)
    return norm(reverb(x * e, 0.7, 0.3, 2500))


def s_flush():
    d = 1.8
    t = T(d)
    x = band(noise(d), 300, 3500) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    x += lp(noise(d), 200) * np.sin(np.pi * np.clip(t / d, 0, 1)) * 0.8
    return norm(reverb(x, 0.8, 0.3, 3000))


def s_hum(d):
    t = T(d)
    flutter = 1 + 0.12 * np.sin(2 * np.pi * 7.5 * t) + 0.06 * np.sin(2 * np.pi * 13 * t)
    x = sum(np.sin(2 * np.pi * 31 * k * t) / k ** 1.2 for k in range(1, 12)) * flutter
    x += band(noise(d), 80, 400) * 0.3
    e = np.minimum(1, t * 4) * np.minimum(1, (d - t) * 6)
    return norm(lp(x, 900) * e)


def s_gauge():
    d = 0.7
    t = T(d)
    x = sweep(1100, 260, d, 'exp') * 0.5 * np.exp(-t * 2)
    for k in range(9):
        n = int((k / 9) * 0.55 * SR)
        c = hp(noise(0.006), 2000) * env_ad(int(0.006 * SR), 0.0002, 0.002)
        x[n:n + len(c)] += c
    return norm(x)


def s_wind(d):
    t = T(d)
    x = band(noise(d), 120, 1400) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.35 * t + 1) ** 2)
    x += band(noise(d), 1500, 3500) * 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.6 * t))
    e = np.minimum(1, t * 2) * np.minimum(1, (d - t) * 2)
    return norm(x * e)


def s_hazard(d):
    x = np.zeros(int(d * SR))
    k = 0
    tt = 0.0
    while tt < d - 0.05:
        n = int(tt * SR)
        c = (tone(1400 if k % 2 == 0 else 1050, 0.01) + hp(noise(0.01), 2000)) * env_ad(int(0.01 * SR), 0.0002, 0.003)
        x[n:n + len(c)] += c
        tt += 0.3125
        k += 1
    return norm(x)


def s_flicker(d):
    t = T(d)
    buzz = sum(np.sin(2 * np.pi * 100 * k * t) / k for k in range(1, 9))
    gate = np.repeat(rng.random(int(d * 30) + 1) > 0.35, SR // 30)[:len(t)].astype(float)
    gate = np.convolve(gate, np.ones(200) / 200, 'same')
    return norm(lp(buzz, 3000) * gate * np.minimum(1, (d - t) * 3))


def s_knock():
    d = 0.5
    t = T(d)
    x = sum(np.sin(2 * np.pi * f * t) * a * np.exp(-t * k) for f, a, k in [(95, 1.0, 22), (190, 0.7, 30), (330, 0.5, 40), (610, 0.25, 60)])
    x += band(noise(d), 400, 3000) * np.exp(-t * 120) * 0.7
    return norm(reverb(np.tanh(x * 1.8), 0.9, 0.35, 2500))


def s_heartbeat(d):
    x = np.zeros(int(d * SR))
    tt = 0.0
    period = 0.78
    while tt < d - 0.3:
        for off, a in [(0, 1.0), (0.17, 0.7)]:
            n = int((tt + off) * SR)
            tb = T(0.22)
            c = np.sin(2 * np.pi * 48 * tb) * np.exp(-tb * 18) * np.minimum(1, tb * 200)
            c = np.tanh(c * 2) * a
            x[n:n + len(c)] += c[:len(x) - n]
        tt += period
        period *= 0.96
    return norm(lp(x, 400))


def s_rewind():
    d = 0.55
    t = T(d)
    x = sweep(400, 3500, d, 'exp', 'saw') * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 34 * t)))
    x = band(x, 300, 6000) * 0.5 + band(noise(d), 2000, 8000) * 0.4 * (0.5 + 0.5 * np.sin(2 * np.pi * 21 * t))
    e = np.minimum(1, t * 20) * np.minimum(1, (d - t) * 30)
    return norm(x * e)


def music(d):
    """Dark tension drone in A minor with slow pulses."""
    t = T(d)
    x = np.zeros(len(t))
    for f, a in [(55, 1.0), (55.3, 0.8), (82.4, 0.5), (110.2, 0.35), (130.8, 0.25)]:
        ph = 2 * np.pi * f * t + 0.3 * np.sin(2 * np.pi * 0.07 * t)
        x += a * sum(np.sin(k * ph) / k ** 1.4 for k in range(1, 7))
    x = band(x, 45, 650)
    x *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.11 * t)
    # pulsing low heartbeat-like synth every beat at 96 bpm
    beat = 60 / 96
    pulse = np.zeros(len(t))
    k = 0
    while k * beat < d:
        n = int(k * beat * SR)
        tb = T(0.35)
        c = np.sin(2 * np.pi * 55 * tb) * np.exp(-tb * 9)
        pulse[n:n + len(c)] += c[:len(t) - n]
        k += 1
    air = band(noise(d), 2000, 8000) * 0.04 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.05 * t))
    return norm(x) * 0.8 + norm(pulse) * 0.35 + air


SOUNDS = {
    'whoosh': lambda e: s_whoosh(False), 'whoosh_soft': lambda e: s_whoosh(True), 'swipe': lambda e: s_swipe(),
    'riser': lambda e: s_riser(e.get('d', 0.9)), 'clack': lambda e: s_clack(), 'powerdown': lambda e: s_powerdown(),
    'boom': lambda e: s_boom(), 'impact': lambda e: s_impact(), 'subdrop': lambda e: s_subdrop(), 'glitch': lambda e: s_glitch(),
    'pop': lambda e: s_pop(), 'tickroll': lambda e: s_tickroll(), 'zap': lambda e: s_zap(), 'honk': lambda e: s_honk(),
    'honk2': lambda e: s_honk(350, 440, 0.32), 'clunk': lambda e: s_clunk(), 'click': lambda e: s_click(), 'beep': lambda e: s_beep(),
    'batterylow': lambda e: s_batterylow(), 'stamp': lambda e: s_stamp(), 'error': lambda e: s_error(), 'cash': lambda e: s_cash(),
    'scan': lambda e: s_scan(), 'gurgle': lambda e: s_gurgle(e.get('d', 1.5)), 'flush': lambda e: s_flush(), 'hum': lambda e: s_hum(e.get('d', 3)),
    'gauge': lambda e: s_gauge(), 'wind': lambda e: s_wind(e.get('d', 3)), 'hazard': lambda e: s_hazard(e.get('d', 3)),
    'flicker': lambda e: s_flicker(e.get('d', 2)), 'knock': lambda e: s_knock(), 'heartbeat': lambda e: s_heartbeat(e.get('d', 3)),
    'rewind': lambda e: s_rewind(),
}
PAN = {'honk': -0.4, 'honk2': 0.45, 'click': 0.2, 'beep': 0.3, 'cash': -0.2, 'hazard': 0.3, 'knock': 0.0, 'error': 0.15}


def main(tl_path, out_path, stems_dir=None):
    tl = json.load(open(tl_path))
    dur = 60.0
    N = int(dur * SR)
    L = np.zeros(N + SR * 3)
    Rr = np.zeros(N + SR * 3)
    for e in tl['SFX']:
        snd = SOUNDS[e['s']](e)
        if isinstance(snd, tuple):
            l, r = snd
        else:
            p = PAN.get(e['s'], 0.0) + rng.uniform(-0.08, 0.08)
            l, r = snd * np.sqrt((1 - p) / 2) * 1.414, snd * np.sqrt((1 + p) / 2) * 1.414
        n = int(max(0, e['t']) * SR)
        g = e['g'] * 0.5
        L[n:n + len(l)] += l * g
        Rr[n:n + len(r)] += r * g
    # music bed with ducking during silence beat and fades
    mus = music(dur + 1)[:N]
    t = np.arange(N) / SR
    menv = np.ones(N)
    menv *= np.clip(t / 0.4, 0, 1)
    menv *= 1 - 0.85 * (np.clip((t - 49.4) / 0.3, 0, 1) * np.clip((51.0 - t) / 0.3, 0, 1))
    menv *= 1 + 0.6 * np.clip((t - 56.5) / 2.3, 0, 1) * (t < 58.9)
    menv *= np.where(t > 59.6, np.clip((60 - t) / 0.4, 0, 1), 1)
    m = mus * menv * tl['MUSIC']['gain']
    L[:N] += m
    Rr[:N] += m * 0.97
    L, Rr = L[:N], Rr[:N]
    mix = np.stack([L, Rr], 1)
    mix = np.tanh(mix * 1.2) / np.tanh(1.2)
    mix = mix / (np.max(np.abs(mix)) + 1e-9) * 0.89
    pcm = (mix * 32767).astype(np.int16)
    with wave.open(out_path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print('wrote', out_path, pcm.shape)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
