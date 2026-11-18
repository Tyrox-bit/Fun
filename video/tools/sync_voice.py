"""Voice-driven sync: sentence spans from pauses + per-sentence DTW word timing,
then writes src/sync.js (new captions + time warp) and out/sync.json (for audio).
Usage: python3 sync_voice.py voice16.wav
"""
import json, re, sys, tempfile
import numpy as np
from align import read_wav, synth, mfcc, dtw, SR, HOP

VOICE_OFFSET = 0.30          # trim this much leading silence from the voice
EXTRA = ["Schreib's in die Kommentare!"]   # spoken in the recording, not in the old script
# manual sentence starts (voice time) verified by voicing + phrase matching
OVERRIDE = {3: 5.42, 26: 49.81, 33: 67.82, 34: 70.12, 35: 72.16, 36: 73.58}

tl = json.load(open('out/timeline.json'))
voice = read_wav(sys.argv[1])

# sentences from the ElevenLabs script
sentences = []
for line in open('out/ElevenLabs_Komplett.txt', encoding='utf-8'):
    m = re.match(r'\[[^\]]*\]\s*(.*)', line.strip())
    if m and 'Pause' not in m[1]:
        sentences.append(re.sub(r'\[[^\]]*\]\s*', '', m[1]).strip().split())
sentences += [s.split() for s in EXTRA]

# speech islands from energy
fr = voice[: len(voice) // HOP * HOP].reshape(-1, HOP)
db = 20 * np.log10(np.sqrt((fr ** 2).mean(1)) + 1e-9)
speech = db > -38
# remove silences shorter than 0.12 s
k = 0
while k < len(speech):
    if not speech[k]:
        j = k
        while j < len(speech) and not speech[j]: j += 1
        if j - k < 12 and k > 0 and j < len(speech): speech[k:j] = True
        k = j
    else: k += 1
onsets = [i * HOP / SR for i in range(1, len(speech)) if speech[i] and not speech[i - 1]]
offsets = [i * HOP / SR for i in range(1, len(speech)) if not speech[i] and speech[i - 1]]
if speech[0]: onsets.insert(0, 0.0)

# coarse global alignment for sentence starts
prior = json.load(open(sys.argv[2])) if len(sys.argv) > 2 else None
coarse = {}
for w in prior['words']:
    coarse.setdefault(w['s'], w['start'])
starts = []
for si in range(len(sentences)):
    if si in OVERRIDE: starts.append(OVERRIDE[si]); continue
    st = coarse[si]
    near = min(onsets, key=lambda o: abs(o - st))
    starts.append(near if abs(near - st) < 0.3 else st)
assert all(b > a for a, b in zip(starts, starts[1:])), starts
ends = []
for si, st in enumerate(starts):
    nxt = starts[si + 1] if si + 1 < len(starts) else len(voice) / SR
    cands = [o for o in offsets if st < o <= nxt + 0.01]
    ends.append(max(cands) if cands else nxt - 0.05)

# per-sentence DTW for word starts
words = []
with tempfile.TemporaryDirectory() as d:
    for si, ws in enumerate(sentences):
        ref, bounds, pos = [], [], 0
        for w in ws:
            clean = re.sub(r"[^\wäöüÄÖÜß']", '', w)
            seg = synth(clean, d) if clean else np.zeros(0, np.float32)
            bounds.append(pos); ref.append(seg); pos += len(seg)
            g = np.zeros(int(0.03 * SR), np.float32); ref.append(g); pos += len(g)
        a0, a1 = max(0, starts[si] - 0.03), ends[si] + 0.03
        first = dtw(mfcc(np.concatenate(ref)).astype(np.float64), mfcc(voice[int(a0 * SR):int(a1 * SR)]).astype(np.float64))
        for wi, (w, b) in enumerate(zip(ws, bounds)):
            t = a0 + first[min(len(first) - 1, b // HOP)] * HOP / SR
            if wi == 0: t = starts[si]
            words.append({'s': si, 'w': w, 't': round(t, 3)})

# map words -> caption chunks (old captions + extra CTA chunks)
caps = [list(c) for c in tl['CAPTIONS']]
cta = [[None, 'WIE LANGE HÄLTST', {}], [None, 'DU DURCH?', {'hl': ['DURCH?']}], [None, "SCHREIB'S IN", {}], [None, 'DIE KOMMENTARE!', {'hl': ['KOMMENTARE!']}]]
allcaps = caps + cta
up = lambda s: s.upper().replace('ß', 'SS')
flat = [up(w['w']) for w in words]
cap_words = [w for c in allcaps for w in c[1].split()]
assert flat == cap_words, [(i, a, b) for i, (a, b) in enumerate(zip(flat, cap_words)) if a != b][:5]
new_caps, wi = [], 0
for c in allcaps:
    n = len(c[1].split())
    t_new = max(0.0, words[wi]['t'] - VOICE_OFFSET - 0.04)
    new_caps.append([round(t_new, 3), c[1], c[2], c[0]])
    wi += n
new_caps[0][0] = 0.0
speech_end = ends[-1] - VOICE_OFFSET
duration = round(speech_end + 0.6, 2)
cap_end = round(speech_end + 0.25, 3)

# time warp anchors (new -> old): every old caption start, plus the ending
anchors = [(c[0], c[3]) for c in new_caps if c[3] is not None]
whisper_end = ends[34] - VOICE_OFFSET
anchors += [(round(whisper_end - 0.15, 3), 58.35), (round(starts[35] - VOICE_OFFSET - 0.12, 3), 58.9), (duration, 60.0)]
anchors.sort()
assert all(b[0] > a[0] and b[1] > a[1] for a, b in zip(anchors, anchors[1:])), anchors

sync = {'duration': duration, 'voiceOffset': VOICE_OFFSET, 'captionEnd': cap_end, 'ctaStart': round(starts[35] - VOICE_OFFSET, 3),
        'captions': [c[:3] for c in new_caps], 'warp': anchors, 'words': words,
        'sentences': [{'t': round(s - VOICE_OFFSET, 3), 'end': round(e - VOICE_OFFSET, 3), 'text': ' '.join(ws)} for s, e, ws in zip(starts, ends, sentences)]}
json.dump(sync, open('out/sync.json', 'w'), ensure_ascii=False, indent=1)
open('src/sync.js', 'w', encoding='utf-8').write('// generated by tools/sync_voice.py from the ElevenLabs voice\nexport const SYNC = ' + json.dumps({k: sync[k] for k in ['duration', 'captionEnd', 'ctaStart', 'captions', 'warp']}, ensure_ascii=False) + ';\n')
print(f'duration {duration}s, {len(new_caps)} caption chunks, {len(words)} words')
for s in sync['sentences']:
    print(f"{s['t']:6.2f}-{s['end']:6.2f}  {s['text']}")
