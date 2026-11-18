"""Final mix on the voice timeline: warped SFX + music bed + ElevenLabs voice with ducking.
Usage: python3 mix_voice.py out/timeline.json out/sync.json voice48_edit.wav out/mix_mit_stimme.wav out/soundspur_ohne_stimme.wav
"""
import json, sys, wave
import numpy as np
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import sfx as S

SR = S.SR


def read_mono(p):
    with wave.open(p) as w:
        assert w.getframerate() == SR, w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32768
        if w.getnchannels() == 2: x = x.reshape(-1, 2).mean(1)
    return x


def write(p, st):
    st = np.clip(st, -1, 1)
    with wave.open(p, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((st * 32767).astype(np.int16).tobytes())


def main(tl_p, sync_p, voice_p, out_mix, out_bed):
    tl, sy = json.load(open(tl_p)), json.load(open(sync_p))
    warp = np.array(sy['warp'])            # columns: new, old
    W = lambda old: float(np.interp(old, warp[:, 1], warp[:, 0]))
    dur = sy['duration']
    N = int(dur * SR)
    # voice first (needed to tame effects that land on spoken words)
    v = read_mono(voice_p)[int(sy['voiceOffset'] * SR):]
    v = np.concatenate([v, np.zeros(max(0, N - len(v)))])[:N]
    v = v / (np.sqrt(np.mean(v[np.abs(v) > 0.01] ** 2)) + 1e-9) * 0.16
    # gentle per-sentence levelling (whispers stay whispers, but audible)
    rms_ = lambda x: np.sqrt(np.mean(x ** 2)) + 1e-9
    spans = [(int(x['t'] * SR), int(x['end'] * SR)) for x in sy['sentences']]
    lv = [rms_(v[a:b][np.abs(v[a:b]) > 0.005]) for a, b in spans]
    target = float(np.median(lv))
    gain = np.ones(N)
    for (a, b), l in zip(spans, lv):
        g = float(np.clip(target / l, 0.8, 1.9))
        a0, b0 = max(0, a - int(0.08 * SR)), min(N, b + int(0.08 * SR))
        gain[a0:b0] = g
    gain = np.convolve(gain, np.ones(2400) / 2400, 'same')
    v = v * gain
    vact = np.convolve((np.abs(v) > 0.02).astype(float), np.ones(2400) / 2400, 'same')
    L = np.zeros(N + SR * 4); R = np.zeros(N + SR * 4)
    for e in tl['SFX']:
        e2 = dict(e)
        t0 = W(max(0, e['t']))
        if 'd' in e: e2['d'] = max(0.2, W(e['t'] + e['d']) - t0)
        snd = S.SOUNDS[e['s']](e2)
        if isinstance(snd, tuple): l, r = snd
        else:
            p = S.PAN.get(e['s'], 0.0)
            l, r = snd * np.sqrt((1 - p) / 2) * 1.414, snd * np.sqrt((1 + p) / 2) * 1.414
        n = int(t0 * SR); g = e['g'] * 0.5
        if e['s'] not in ('hum', 'wind', 'hazard', 'flicker', 'heartbeat') and vact[n:n + int(0.5 * SR)].mean() > 0.15: g *= 0.5
        L[n:n + len(l)] += l * g; R[n:n + len(r)] += r * g
    # extra: soft pop + whoosh for the spoken call-to-action (new time)
    cta = sy['ctaStart']
    for snd, t0, g in [(S.s_whoosh(True), cta - 0.3, 0.3), (S.s_pop(), cta, 0.25)]:
        l, r = snd if isinstance(snd, tuple) else (snd, snd)
        n = int(t0 * SR); L[n:n + len(l)] += l * g; R[n:n + len(r)] += r * g
    L, R = L[:N], R[:N]
    t = np.arange(N) / SR
    mus = S.music(dur + 1)[:N]
    menv = np.clip(t / 0.4, 0, 1)
    a, b = W(49.4), W(51.0)
    menv *= 1 - 0.85 * (np.clip((t - a) / 0.3, 0, 1) * np.clip((b - t) / 0.3, 0, 1))
    c0, c1 = W(56.5), W(58.9)
    menv *= 1 + 0.6 * np.clip((t - c0) / (c1 - c0), 0, 1) * (t < c1)
    menv *= np.where(t > dur - 0.4, np.clip((dur - t) / 0.4, 0, 1), 1)
    m = mus * menv * tl['MUSIC']['gain']
    bedL, bedR = L + m, R + m * 0.97

    # ducking envelope (attack 30 ms, release 350 ms)
    rect = np.abs(v)
    env = np.zeros(N); a_c, r_c = np.exp(-1 / (0.03 * SR)), np.exp(-1 / (0.35 * SR))
    # fast envelope on 1 ms blocks
    blk = SR // 1000
    rb = rect[: N // blk * blk].reshape(-1, blk).max(1)
    eb = np.zeros_like(rb); prev = 0.0
    ac, rc = np.exp(-1 / 30), np.exp(-1 / 350)
    for i, x in enumerate(rb):
        k = ac if x > prev else rc
        prev = k * prev + (1 - k) * x; eb[i] = prev
    env[: len(eb) * blk] = np.repeat(eb, blk)
    env = np.clip(env / (np.percentile(eb[eb > 0.005], 90) + 1e-9), 0, 1)
    duck = 1 - 0.65 * env
    bed = np.stack([bedL, bedR], 1)
    bed = np.tanh(bed * 1.2) / np.tanh(1.2)
    bed /= np.max(np.abs(bed)) + 1e-9
    write(out_bed, bed * 0.89)
    bed_d = bed * 0.55 * duck[:, None]
    mix = bed_d + v[:, None] * 1.0
    act = np.convolve((np.abs(v) > 0.02).astype(float), np.ones(4800) / 4800, 'same') > 0.3
    rms = lambda x: np.sqrt(np.mean(x ** 2)) + 1e-9
    bm = S.band(bed_d.mean(1), 300, 4000); v_m = S.band(v, 300, 4000)
    print(f'Stimme vs. Effekte beim Sprechen: {20 * np.log10(rms(v_m[act]) / rms(bm[act])):.1f} dB')
    res = []
    for i in range(0, N - SR // 2, SR // 2):
        sl = slice(i, i + SR // 2)
        if act[sl].mean() > 0.5: res.append((round(20 * np.log10(rms(v_m[sl]) / rms(bm[sl])), 1), round(i / SR, 1)))
    print('knappste Stellen (dB, s):', sorted(res)[:6])
    mix = mix / (np.max(np.abs(mix)) + 1e-9) * 0.95
    write(out_mix, mix)
    print('wrote', out_mix, out_bed, f'{dur:.2f}s')


if __name__ == '__main__':
    main(*sys.argv[1:6])
