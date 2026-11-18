"""Forced alignment without a speech recogniser:
espeak-ng speaks the known script word by word -> reference audio with known word boundaries,
then MFCC + DTW maps the reference onto the real voice recording.
Usage: python3 align.py voice.wav ElevenLabs_Komplett.txt out.json
"""
import json, re, subprocess, sys, tempfile, wave, os
import numpy as np
from numba import njit

SR = 16000
HOP = 160  # 10 ms
WIN = 400  # 25 ms


def read_wav(p):
    with wave.open(p) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768
        if w.getnchannels() > 1:
            x = x.reshape(-1, w.getnchannels()).mean(1)
        sr = w.getframerate()
    if sr != SR:
        raise SystemExit(f'expected {SR} Hz, got {sr}')
    return x


def synth(text, d):
    p = os.path.join(d, 'w.wav')
    subprocess.run(['espeak-ng', '-v', 'de', '-s', '165', '-w', p, text], check=True)
    q = os.path.join(d, 'w16.wav')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', p, '-ac', '1', '-ar', str(SR), q], check=True)
    x = read_wav(q)
    e = np.abs(x) > 0.01
    if not e.any():
        return np.zeros(0, np.float32)
    i0, i1 = np.argmax(e), len(e) - np.argmax(e[::-1])
    return x[max(0, i0 - 80):i1 + 80]


def mel_fb(n_fft, n_mels=26, fmin=60, fmax=7600):
    hz2mel = lambda f: 2595 * np.log10(1 + f / 700)
    mel2hz = lambda m: 700 * (10 ** (m / 2595) - 1)
    pts = mel2hz(np.linspace(hz2mel(fmin), hz2mel(fmax), n_mels + 2))
    bins = np.floor((n_fft + 1) * pts / SR).astype(int)
    fb = np.zeros((n_mels, n_fft // 2 + 1))
    for m in range(1, n_mels + 1):
        a, b, c = bins[m - 1], bins[m], bins[m + 1]
        for k in range(a, b): fb[m - 1, k] = (k - a) / max(b - a, 1)
        for k in range(b, c): fb[m - 1, k] = (c - k) / max(c - b, 1)
    return fb


FB = mel_fb(512)
DCT = np.cos(np.pi / 26 * (np.arange(26)[None, :] + 0.5) * np.arange(13)[:, None])


def mfcc(x):
    x = np.append(x[0], x[1:] - 0.97 * x[:-1])
    n = 1 + max(0, (len(x) - WIN) // HOP)
    idx = np.arange(WIN)[None, :] + HOP * np.arange(n)[:, None]
    fr = x[idx] * np.hamming(WIN)
    spec = np.abs(np.fft.rfft(fr, 512)) ** 2
    mel = np.log(spec @ FB.T + 1e-8)
    c = mel @ DCT.T
    energy = np.log(np.sum(fr ** 2, 1) + 1e-8)
    feat = np.concatenate([c[:, 1:], energy[:, None]], 1)
    d = np.gradient(feat, axis=0)
    feat = np.concatenate([feat, d * 0.5], 1)
    return (feat - feat.mean(0)) / (feat.std(0) + 1e-6)


@njit(cache=True)
def dtw(a, b):
    n, m = a.shape[0], b.shape[0]
    D = np.full((n + 1, m + 1), np.inf)
    D[0, 0] = 0.0
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            c = 0.0
            for k in range(a.shape[1]):
                t = a[i - 1, k] - b[j - 1, k]
                c += t * t
            c = np.sqrt(c)
            best = D[i - 1, j - 1]
            if D[i - 1, j] < best: best = D[i - 1, j]
            if D[i, j - 1] < best: best = D[i, j - 1]
            D[i, j] = c + best
    # backtrack: for each ref frame i, the first matching voice frame
    first = np.full(n, -1)
    i, j = n, m
    while i > 0 and j > 0:
        first[i - 1] = j - 1
        d0, d1, d2 = D[i - 1, j - 1], D[i - 1, j], D[i, j - 1]
        if d0 <= d1 and d0 <= d2: i -= 1; j -= 1
        elif d1 <= d2: i -= 1
        else: j -= 1
    return first


def main(voice_path, script_path, out_path):
    sentences = []
    for line in open(script_path, encoding='utf-8'):
        m = re.match(r'\[[^\]]*\]\s*(.*)', line.strip())
        if not m or 'Pause' in m[1]:
            continue
        text = re.sub(r'\[[^\]]*\]\s*', '', m[1]).strip()
        sentences.append(text.split())
    words = [(si, w) for si, s in enumerate(sentences) for w in s]
    print('words:', len(words), 'sentences:', len(sentences))

    voice = read_wav(voice_path)
    ref, bounds = [np.zeros(int(0.4 * SR), np.float32)], []
    pos = len(ref[0])
    with tempfile.TemporaryDirectory() as d:
        for k, (si, w) in enumerate(words):
            clean = re.sub(r"[^\wäöüÄÖÜß']", '', w)
            seg = synth(clean, d) if clean else np.zeros(0, np.float32)
            bounds.append((pos, pos + len(seg)))
            ref.append(seg); pos += len(seg)
            last = k + 1 == len(words) or words[k + 1][0] != si
            gap = np.zeros(int((0.32 if last else 0.03) * SR), np.float32)
            ref.append(gap); pos += len(gap)
    ref = np.concatenate(ref)
    fa, fb = mfcc(ref), mfcc(voice)
    print('frames ref/voice:', len(fa), len(fb))
    first = dtw(fa.astype(np.float64), fb.astype(np.float64))
    tmap = lambda sample: first[min(len(first) - 1, sample // HOP)] * HOP / SR
    out = []
    for (si, w), (a, b) in zip(words, bounds):
        out.append({'s': si, 'w': w, 'start': round(float(tmap(a)), 3), 'end': round(float(tmap(max(a, b - 1))), 3)})
    json.dump({'words': out, 'duration': len(voice) / SR}, open(out_path, 'w'), ensure_ascii=False, indent=1)
    print('wrote', out_path)


if __name__ == '__main__':
    main(*sys.argv[1:4])
