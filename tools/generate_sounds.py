#!/usr/bin/env python3
"""Synthesizes the original FREQUENCY ZERO sound effects (no samples, no third-party audio).

Every sound is generated from noise, oscillators and simple filters, so the results are
fully ours and can be uploaded to Roblox without licensing questions.
Output: assets/audio/<name>.ogg (needs ffmpeg) - upload them in the Creator Hub and put
the resulting asset ids into src/ReplicatedStorage/Shared/Assets.luau.

Loudness policy: no sound peaks above -6 dBFS, ambience loops sit around -20 dBFS.

Usage: python3 tools/generate_sounds.py
"""
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
SR = 44100
rng = np.random.default_rng(1402)  # fixed seed: reproducible builds


# --------------------------------------------------------------------------- helpers
def t(seconds):
    return np.arange(int(seconds * SR)) / SR


def noise(seconds):
    return rng.uniform(-1, 1, int(seconds * SR))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, low, high):
    return lowpass(highpass(x, low), high)


def env(n, attack=0.005, release=0.1, hold=None):
    e = np.ones(n)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    if hold is not None:
        h = int(hold * SR)
        e[a + h:] = 0
        tail = min(r, n - (a + h)) if n > a + h else 0
        if tail > 0:
            e[a + h:a + h + tail] = np.linspace(1, 0, tail)
    else:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def decay(n, seconds):
    return np.exp(-np.arange(n) / (seconds * SR))


def normalize(x, peak_db):
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * (10 ** (peak_db / 20))


def make_loop(x, fade=0.25):
    """Crossfades the tail into the head so the sound loops without a click."""
    f = int(fade * SR)
    head, body, tail = x[:f], x[f:-f], x[-f:]
    ramp = np.linspace(0, 1, f)
    return np.concatenate([body, tail * (1 - ramp) + head * ramp])


def crackle(seconds, density):
    out = np.zeros(int(seconds * SR))
    count = int(seconds * density)
    for pos in rng.integers(0, len(out) - 400, count):
        length = int(rng.integers(20, 300))
        out[pos:pos + length] += rng.uniform(-1, 1, length) * decay(length, 0.002) * rng.uniform(0.3, 1)
    return out


def tone(freq, seconds, wave_type="sine"):
    phase = 2 * np.pi * freq * t(seconds)
    if wave_type == "square":
        return np.sign(np.sin(phase))
    if wave_type == "saw":
        return 2 * ((freq * t(seconds)) % 1) - 1
    return np.sin(phase)


# --------------------------------------------------------------------------- sounds
def radio_static_loop():
    s = bandpass(noise(4), 300, 3200) * 0.6 + crackle(4, 18) * 0.5
    s *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.7 * t(4))
    return make_loop(normalize(s, -18))


def radio_squelch_on():
    n = bandpass(noise(0.18), 400, 3000) * decay(int(0.18 * SR), 0.06)
    click = np.zeros_like(n)
    click[:60] = np.linspace(1, 0, 60)
    return normalize(n * 0.7 + click, -9)


def radio_squelch_off():
    beep = tone(1250, 0.07) * env(int(0.07 * SR), 0.003, 0.01)
    tail = bandpass(noise(0.22), 400, 3000) * decay(int(0.22 * SR), 0.05) * 0.6
    return normalize(np.concatenate([beep, tail]), -10)


def radio_channel_beep():
    a = tone(880, 0.05) * env(int(0.05 * SR), 0.002, 0.01)
    b = tone(1320, 0.05) * env(int(0.05 * SR), 0.002, 0.01)
    return normalize(np.concatenate([a, np.zeros(int(0.02 * SR)), b]), -14)


def hum_electric_loop():
    x = t(4)
    s = sum(np.sin(2 * np.pi * 50 * k * x) / k ** 1.3 for k in range(1, 8))
    s *= 0.9 + 0.1 * np.sin(2 * np.pi * 0.25 * x)
    s += bandpass(noise(4), 2000, 6000) * 0.02
    return make_loop(normalize(s, -22))


def generator_loop():
    x = t(4)
    s = np.sin(2 * np.pi * 31 * x) * 0.6 + np.sin(2 * np.pi * 62 * x) * 0.3
    s *= 0.7 + 0.3 * (np.sin(2 * np.pi * 7.5 * x) > 0)
    s += lowpass(noise(4), 250) * 0.6
    return make_loop(normalize(s, -18))


def ambience_wind_loop():
    seconds = 10
    s = lowpass(noise(seconds), 400) * 3
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * 0.11 * t(seconds)) * np.sin(2 * np.pi * 0.047 * t(seconds) + 1)
    s = s * gust + bandpass(noise(seconds), 800, 1600) * 0.04 * gust
    return make_loop(normalize(s, -20), 0.8)


def creature_click():
    out = np.zeros(int(0.45 * SR))
    pos = 0
    for _ in range(5):
        length = int(rng.integers(150, 500))
        burst = bandpass(noise(length / SR), 1200, 5000) * decay(length, 0.004)
        out[pos:pos + length] += burst
        pos += int(rng.integers(1500, 4000))
        if pos + 600 > len(out):
            break
    return normalize(out, -8)


def creature_static_burst():
    seconds = 0.5
    s = bandpass(noise(seconds), 200, 6000)
    gate = (np.sin(2 * np.pi * 23 * t(seconds)) > -0.2).astype(float)  # signal dropouts
    s *= gate * env(len(s), 0.01, 0.15)
    return normalize(s + crackle(seconds, 60) * 0.6, -7)


def creature_breath():
    seconds = 2.4
    x = t(seconds)
    shape = np.clip(np.sin(np.pi * x / seconds), 0, 1) ** 1.5
    s = bandpass(noise(seconds), 150, 900) * shape
    s += np.sin(2 * np.pi * 70 * x + 3 * np.sin(2 * np.pi * 0.8 * x)) * 0.15 * shape
    return normalize(s, -14)


def creature_alert():
    seconds = 1.1
    x = t(seconds)
    freq = 420 * np.exp(-x * 1.6) + 90
    phase = 2 * np.pi * np.cumsum(freq) / SR
    s = np.tanh(3 * np.sin(phase)) * 0.6 + bandpass(noise(seconds), 300, 5000) * 0.5
    s *= env(len(s), 0.02, 0.4)
    return normalize(s, -6)


def heartbeat_loop():
    beat = np.zeros(int(0.9 * SR))
    for offset, strength in ((0, 1.0), (0.22, 0.7)):
        n = int(0.12 * SR)
        thump = np.sin(2 * np.pi * 55 * t(0.12)) * decay(n, 0.03) * strength
        i = int(offset * SR)
        beat[i:i + n] += thump
    return normalize(beat, -10)


def footstep(material, seed):
    local = np.random.default_rng(seed)
    seconds = 0.22
    n = int(seconds * SR)
    raw = local.uniform(-1, 1, n)
    if material == "concrete":
        s = bandpass(raw, 120, 2600) * decay(n, 0.025)
        s += np.sin(2 * np.pi * 85 * t(seconds)) * decay(n, 0.02) * 0.6
        peak = -16
    elif material == "metal":
        s = bandpass(raw, 300, 5000) * decay(n, 0.03)
        for f in (430, 910, 1570):
            s += np.sin(2 * np.pi * f * local.uniform(0.97, 1.03) * t(seconds)) * decay(n, 0.06) * 0.25
        peak = -15
    else:  # grass / gravel
        s = np.zeros(n)
        for _ in range(14):
            pos = int(local.integers(0, n - 400))
            length = int(local.integers(80, 400))
            s[pos:pos + length] += bandpass(local.uniform(-1, 1, length), 1500, 7000) * decay(length, 0.004)
        s *= env(n, 0.005, 0.08)
        peak = -18
    return normalize(s, peak)


def door_open():
    seconds = 1.2
    slide = bandpass(noise(seconds), 150, 1200) * env(int(seconds * SR), 0.1, 0.3) * 0.5
    clunk = np.zeros(int(seconds * SR))
    n = int(0.25 * SR)
    clunk[-n:] = np.sin(2 * np.pi * 70 * t(0.25)) * decay(n, 0.05) + bandpass(noise(0.25), 100, 900) * decay(n, 0.03)
    return normalize(slide + clunk, -9)


def door_locked():
    buzz = tone(110, 0.35, "square") * 0.3 + tone(220, 0.35, "saw") * 0.15
    return normalize(lowpass(buzz, 1800) * env(int(0.35 * SR), 0.005, 0.05), -12)


def fuse_pickup():
    seconds = 0.5
    s = sum(np.sin(2 * np.pi * f * t(seconds)) * decay(int(seconds * SR), d) for f, d in ((1850, 0.08), (2730, 0.05), (960, 0.12)))
    return normalize(s, -12)


def relay_activate():
    seconds = 2.0
    x = t(seconds)
    freq = 40 + 70 * (x / seconds) ** 2
    hum = np.sin(2 * np.pi * np.cumsum(freq) / SR) + 0.4 * np.sin(4 * np.pi * np.cumsum(freq) / SR)
    hum *= env(len(hum), 0.3, 0.2)
    clunk = np.zeros_like(hum)
    n = int(0.3 * SR)
    clunk[:n] = bandpass(noise(0.3), 80, 1500) * decay(n, 0.05) * 1.5
    return normalize(hum * 0.6 + clunk, -8)


def power_down():
    seconds = 2.2
    x = t(seconds)
    freq = 120 * np.exp(-x * 1.2) + 20
    s = np.sin(2 * np.pi * np.cumsum(freq) / SR) * env(len(x), 0.01, 0.6)
    return normalize(s + crackle(seconds, 8) * 0.3, -9)


def vent_rattle():
    seconds = 1.6
    out = np.zeros(int(seconds * SR))
    pos = 0
    while pos < len(out) - 3000:
        length = int(rng.integers(600, 2500))
        hit = bandpass(noise(length / SR), 400, 4000) * decay(length, 0.012)
        for f in (520, 1330):
            hit += np.sin(2 * np.pi * f * t(length / SR)) * decay(length, 0.02) * 0.2
        out[pos:pos + length] += hit * rng.uniform(0.4, 1)
        pos += int(rng.integers(900, 4000))
    return normalize(out * env(len(out), 0.02, 0.3), -9)


def ui_focus():
    return normalize(tone(1900, 0.03) * decay(int(0.03 * SR), 0.008), -24)


def ui_select():
    s = np.concatenate([tone(1400, 0.025), tone(2100, 0.035)])
    s = s * decay(len(s), 0.02)
    return normalize(s, -18)


def stinger_low():
    seconds = 3.5
    x = t(seconds)
    s = sum(np.sin(2 * np.pi * f * x + rng.uniform(0, 6)) for f in (55, 58.3, 82.4, 116.5))
    s += bandpass(noise(seconds), 200, 2500) * 0.3
    s *= np.clip(x / 2.0, 0, 1) ** 2 * env(len(x), 0.01, 0.8)
    return normalize(s, -8)


def music_menu():
    seconds = 24
    x = t(seconds)
    s = np.zeros_like(x)
    for f, phase in ((55, 0), (82.4, 1.3), (110, 2.1), (164.8, 0.4)):
        s += np.sin(2 * np.pi * f * x + phase) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.05 * x + phase))
    s = lowpass(s, 900) + bandpass(noise(seconds), 300, 1200) * 0.05
    return make_loop(normalize(s, -20), 2.0)


def tension_low():
    seconds = 16
    x = t(seconds)
    s = np.sin(2 * np.pi * 41.2 * x) + 0.5 * np.sin(2 * np.pi * 43.6 * x)  # slow beating
    s += bandpass(noise(seconds), 60, 400) * 0.4 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.09 * x))
    return make_loop(normalize(s, -20), 1.5)


def tension_high():
    seconds = 8
    x = t(seconds)
    pulse = (np.sin(2 * np.pi * 1.6 * x) > 0.6).astype(float)
    pulse = lowpass(pulse, 30)
    s = np.sin(2 * np.pi * 55 * x) * pulse * 0.9
    s += sum(np.sin(2 * np.pi * f * x) for f in (233.1, 246.9)) * 0.12  # dissonant minor second
    s += bandpass(noise(seconds), 2000, 6000) * 0.05
    return make_loop(normalize(s, -14), 0.5)


# --------------------------------------------------------------------------- 0.5: creature identity
def resonator(x, freq, q):
    """Two-pole resonant band-pass (formants, body resonances)."""
    w = 2 * np.pi * freq / SR
    r = np.exp(-w / (2 * q))
    a1, a2 = -2 * r * np.cos(w), r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    gain = 1 - r
    for i, v in enumerate(x):
        out = gain * v - a1 * y1 - a2 * y2
        y2, y1 = y1, out
        y[i] = out
    return y


def glottal(seconds, f0, jitter, local):
    """Pulse train with irregular pitch - the 'throat' of the creature."""
    n = int(seconds * SR)
    out = np.zeros(n)
    pos = 0.0
    while pos < n:
        out[int(pos)] = 1.0
        period = SR / max(20.0, f0 * (1 + local.uniform(-jitter, jitter)))
        pos += period
    return lowpass(out, 1200)


def breath_deep(seed):
    local = np.random.default_rng(seed)
    seconds = local.uniform(2.4, 3.4)
    n = int(seconds * SR)
    x = np.arange(n) / SR
    split = local.uniform(0.35, 0.55)
    shape = np.where(x < seconds * split, np.sin(np.pi * x / (seconds * split)), 0.7 * np.sin(np.pi * (x - seconds * split) / (seconds * (1 - split))))
    shape = np.clip(shape, 0, 1) ** 1.3
    air = local.uniform(-1, 1, n)
    s = resonator(air, local.uniform(280, 380), 4) * 2 + resonator(air, local.uniform(700, 900), 5)
    s += glottal(seconds, local.uniform(38, 52), 0.35, local) * 0.8  # wet, irregular rattle
    s *= shape * (0.8 + 0.2 * np.sin(2 * np.pi * local.uniform(5, 9) * x))
    return normalize(s, -12)


def growl(seed):
    local = np.random.default_rng(seed)
    seconds = local.uniform(1.2, 2.0)
    n = int(seconds * SR)
    x = np.arange(n) / SR
    voice = glottal(seconds, local.uniform(55, 75), 0.25, local)
    rasp = local.uniform(-1, 1, n) * (0.5 + 0.5 * np.sin(2 * np.pi * local.uniform(28, 40) * x))
    s = resonator(voice * 3 + rasp * 0.4, local.uniform(450, 600), 3) + resonator(voice, 160, 2) * 1.5
    s = np.tanh(s * 6) * env(n, 0.12, 0.4)
    return normalize(s, -10)


def crack(seed):
    local = np.random.default_rng(seed)
    seconds = 0.6
    n = int(seconds * SR)
    out = np.zeros(n)
    pos = 0
    for _ in range(local.integers(2, 6)):
        length = int(local.integers(200, 900))
        if pos + length >= n:
            break
        click = local.uniform(-1, 1, length) * decay(length, 0.003)
        out[pos:pos + length] += resonator(click, local.uniform(900, 2400), 8) * 4
        pos += int(local.integers(800, 3500))
    return normalize(out, -14)


def drag_step(seed):
    local = np.random.default_rng(seed)
    seconds = local.uniform(0.9, 1.3)
    n = int(seconds * SR)
    thump = np.zeros(n)
    m = int(0.18 * SR)
    thump[:m] = np.sin(2 * np.pi * 60 * np.arange(m) / SR) * decay(m, 0.05)
    scrape = bandpass(local.uniform(-1, 1, n), 300, 2500) * env(n, 0.08, 0.35) * 0.35
    scrape *= 0.6 + 0.4 * np.sin(2 * np.pi * local.uniform(11, 17) * np.arange(n) / SR)
    return normalize(thump + scrape, -14)


def rhythm():
    """Three knocks, slightly wrong in time - nothing alive knocks like that."""
    seconds = 3.2
    out = np.zeros(int(seconds * SR))
    for at in (0.0, 0.41, 0.97, 1.6, 2.02, 2.71):
        i = int(at * SR)
        m = int(0.12 * SR)
        hit = resonator(rng.uniform(-1, 1, m) * decay(m, 0.01), 180, 6) * 6 + np.sin(2 * np.pi * 70 * np.arange(m) / SR) * decay(m, 0.04)
        out[i:i + m] += hit[: len(out) - i]
    return normalize(lowpass(out, 2500), -12)


def voices_muffled(seed):
    local = np.random.default_rng(seed)
    seconds = 4.0
    n = int(seconds * SR)
    x = np.arange(n) / SR
    s = np.zeros(n)
    for speaker in range(local.integers(2, 4)):
        f0 = local.uniform(95, 190)
        voice = glottal(seconds, f0, 0.08, local)
        formant = resonator(voice, local.uniform(500, 750), 5) + resonator(voice, local.uniform(1100, 1600), 6) * 0.6
        syllables = (np.sin(2 * np.pi * local.uniform(3, 5) * x + local.uniform(0, 6)) > local.uniform(-0.2, 0.3)).astype(float)
        s += formant * lowpass(syllables, 12)
    s = lowpass(s, 700)  # through a wall
    return make_loop(normalize(s, -20), 0.5)


def speaker_voice(seed):
    local = np.random.default_rng(seed)
    seconds = 3.0
    n = int(seconds * SR)
    x = np.arange(n) / SR
    voice = glottal(seconds, local.uniform(110, 140), 0.12, local)
    s = resonator(voice, 650, 5) + resonator(voice, 1250, 6) * 0.7 + resonator(voice, 2400, 8) * 0.3
    s *= lowpass((np.sin(2 * np.pi * 4.2 * x + local.uniform(0, 3)) > 0).astype(float), 15)
    s = bandpass(np.tanh(s * 8), 400, 3200) + bandpass(local.uniform(-1, 1, n), 1000, 5000) * 0.15
    gate = (local.uniform(0, 1, n // 2000 + 1) > 0.15).repeat(2000)[:n]  # dropouts
    return normalize(s * lowpass(gate.astype(float), 40), -14)


def approach():
    """Something walks closer down a corridor: steps speed up and get louder, then stop."""
    seconds = 6.5
    out = np.zeros(int(seconds * SR))
    t_ = 0.0
    interval = 0.85
    while t_ < seconds - 0.6:
        i = int(t_ * SR)
        m = int(0.3 * SR)
        loudness = 0.15 + 0.85 * (t_ / seconds) ** 1.6
        hit = lowpass(rng.uniform(-1, 1, m), 400 + 2500 * (t_ / seconds)) * decay(m, 0.04) * loudness
        hit += np.sin(2 * np.pi * 55 * np.arange(m) / SR) * decay(m, 0.06) * loudness
        out[i:i + m] += hit
        t_ += interval
        interval = max(0.38, interval * 0.93)
    return normalize(out, -12)


def glass_tap():
    seconds = 0.5
    s = sum(np.sin(2 * np.pi * f * t(seconds)) * decay(int(seconds * SR), d) for f, d in ((2900, 0.05), (4300, 0.03), (1700, 0.08)))
    return normalize(s, -16)


def light_click():
    n = int(0.25 * SR)
    s = np.zeros(n)
    s[:200] = rng.uniform(-1, 1, 200) * decay(200, 0.002)
    s += np.sin(2 * np.pi * 100 * np.arange(n) / SR) * decay(n, 0.05) * 0.3
    return normalize(s, -14)


SOUNDS = {
    "radio_static_loop": radio_static_loop,
    "radio_squelch_on": radio_squelch_on,
    "radio_squelch_off": radio_squelch_off,
    "radio_channel_beep": radio_channel_beep,
    "hum_electric_loop": hum_electric_loop,
    "generator_loop": generator_loop,
    "ambience_wind_loop": ambience_wind_loop,
    "creature_click": creature_click,
    "creature_static_burst": creature_static_burst,
    "creature_breath": creature_breath,
    "creature_alert": creature_alert,
    "heartbeat": heartbeat_loop,
    "footstep_concrete_1": lambda: footstep("concrete", 11),
    "footstep_concrete_2": lambda: footstep("concrete", 12),
    "footstep_concrete_3": lambda: footstep("concrete", 13),
    "footstep_metal_1": lambda: footstep("metal", 21),
    "footstep_metal_2": lambda: footstep("metal", 22),
    "footstep_grass_1": lambda: footstep("grass", 31),
    "footstep_grass_2": lambda: footstep("grass", 32),
    "door_open": door_open,
    "door_locked": door_locked,
    "fuse_pickup": fuse_pickup,
    "relay_activate": relay_activate,
    "power_down": power_down,
    "vent_rattle": vent_rattle,
    "ui_focus": ui_focus,
    "ui_select": ui_select,
    "stinger_low": stinger_low,
    # 0.4 additions (appended at the end so earlier sounds stay identical)
    "music_menu": music_menu,
    "tension_low": tension_low,
    "tension_high": tension_high,
    # 0.5 creature identity and director events (appended: earlier sounds stay identical)
    "creature_breath_deep_1": lambda: breath_deep(101),
    "creature_breath_deep_2": lambda: breath_deep(102),
    "creature_breath_deep_3": lambda: breath_deep(103),
    "creature_growl_1": lambda: growl(201),
    "creature_growl_2": lambda: growl(202),
    "creature_growl_3": lambda: growl(203),
    "creature_crack_1": lambda: crack(301),
    "creature_crack_2": lambda: crack(302),
    "creature_crack_3": lambda: crack(303),
    "creature_crack_4": lambda: crack(304),
    "creature_drag_1": lambda: drag_step(401),
    "creature_drag_2": lambda: drag_step(402),
    "creature_drag_3": lambda: drag_step(403),
    "creature_rhythm": rhythm,
    "voices_muffled_1": lambda: voices_muffled(501),
    "voices_muffled_2": lambda: voices_muffled(502),
    "speaker_voice_1": lambda: speaker_voice(601),
    "speaker_voice_2": lambda: speaker_voice(602),
    "approach_corridor": approach,
    "glass_tap": glass_tap,
    "light_click": light_click,
}


def write_wav(path, samples):
    data = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ffmpeg = shutil.which("ffmpeg")
    for name, build in SOUNDS.items():
        samples = build()
        wav = OUT / f"{name}.wav"
        write_wav(wav, samples)
        if ffmpeg:
            ogg = OUT / f"{name}.ogg"
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5", str(ogg)], check=True)
            wav.unlink()
        print(f"{name}: {len(samples) / SR:.2f}s")
    print(f"wrote {len(SOUNDS)} sounds to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
