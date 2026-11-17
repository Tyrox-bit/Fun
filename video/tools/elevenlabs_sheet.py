"""Builds the ElevenLabs voiceover sheet (HTML + TXT) and checks that every caption word is included."""
import json, re, html

tl = json.load(open('out/timeline.json'))
caps, cap_end = tl['CAPTIONS'], tl['CAPTION_END']

# (tag, text) per sentence, in caption order
LINES = [
    ('[serious]', 'Ganz Deutschland.'), ('[dramatic]', 'Kein Strom.'), ('', '72 Stunden.'), ('[chuckles]', 'Die erste Stunde ist noch lustig.'),
    ('[excited]', 'Minute 1:'), ('', 'Ampeln aus.'), ('', 'Aufzüge stecken fest.'), ('[amused]', 'Alle zücken die Handylampe.'),
    ('[laughs]', 'Fühlt sich noch an wie ein Abenteuer.'),
    ('[serious]', 'Stunde 3:'), ('', 'Viele Funkmasten laufen nur noch auf Akku.'), ('[dramatic]', 'Dann ist Schluss.'),
    ('', 'Kein Netz, kein WhatsApp, kein Notruf.'), ('[sarcastic]', 'Dein Handy ist jetzt eine Taschenlampe.'),
    ('[serious]', 'Stunde 12:'), ('', 'Tankstellen geben kein Benzin mehr raus, denn die Pumpen brauchen Strom.'),
    ('[annoyed]', 'Karte geht nicht, Geldautomat auch nicht.'), ('', 'Kein Bargeld heißt:'), ('[serious]', 'Du kaufst nichts mehr.'),
    ('[tense]', 'Stunde 24:'), ('', 'In Hochhäusern kommt oben kein Wasser mehr an.'), ('[sighs]', 'Keine Dusche.'),
    ('[nervous laugh]', 'Und die Toilette spült genau noch ein Mal.'),
    ('[serious]', 'Stunde 48:'), ('', 'Krankenhäuser laufen auf Notstrom.'), ('[ominous]', 'Mit Diesel.'),
    ('', 'Den muss jemand liefern, über Straßen ohne Ampeln und mit LKWs, die nicht tanken können.'),
    ('[quietly]', 'Stunde 72:'), ('', 'Supermärkte leer.'), ('', 'Kühlschränke warm.'), ('[whispers]', 'Jemand klopft an deine Tür.'),
    ('[whispers]', 'Und jetzt die Frage, die keiner hören will:'),
    ('[serious]', 'Der Staat empfiehlt Vorräte für 10 Tage.'), ('[skeptical]', 'Du hast wahrscheinlich nicht mal welche für 3.'),
    ('[curious]', 'Wie lange würdest du durchhalten?'), ('[excited]', "Schreib's in die Kommentare!"),
    ('[whispers]', 'Denn genau so fängt es an …'),
]

# group caption chunks into sentences exactly like the video does
groups, cur = [], None
for t, txt, _ in caps:
    if cur is None: cur = {'t': t, 'txt': []}
    cur['txt'].append(txt)
    if re.search(r'[.:…?!]$', txt.strip()): groups.append(cur); cur = None
assert cur is None and len(groups) == len(LINES), (len(groups), len(LINES))
norm = lambda s: re.sub(r'\s+', ' ', s.upper()).strip()
for g, (_, text) in zip(groups, LINES):
    want = norm(' '.join(g['txt']))
    assert norm(text) == want, (text, want)
print(f'OK: {len(LINES)} Sätze, alle {sum(len(norm(" ".join(g["txt"])).split()) for g in groups)} Wörter identisch mit den Untertiteln')

rows = []
for i, (g, (tag, text)) in enumerate(zip(groups, LINES)):
    start = g['t']
    end = 49.4 if text.startswith('Und jetzt die Frage') else (groups[i + 1]['t'] if i + 1 < len(groups) else cap_end)
    rows.append((start, end, tag, text))
fmt = lambda s: f'{int(s // 60)}:{s % 60:05.2f}'.replace('.', ',')
line = lambda tag, text: f'{tag} {text}'.strip()

# TXT
txt = ['ELEVENLABS VOICEOVER – 72 STUNDEN OHNE STROM', 'Modell: Eleven v3 (nur da funktionieren die [Tags])', '',
       '=== ALLES AUF EINMAL (zum Komplett-Generieren) ===', '']
txt += [line(t, x) for _, _, t, x in rows]
txt += ['', '=== EINZELN MIT ZEITEN ===', '']
for i, (s, e, t, x) in enumerate(rows, 1):
    txt.append(f'{i:02d} | {fmt(s)} bis {fmt(e)} (max. {f'{e - s:.1f}'.replace('.', ',')} s) | {line(t, x)}')
open('out/ElevenLabs_Voiceover.txt', 'w', encoding='utf-8').write('\n'.join(txt) + '\n')

# HTML
def esc(s): return html.escape(s)
items = []
for i, (s, e, t, x) in enumerate(rows, 1):
    hour = bool(re.match(r'(Minute|Stunde) \d+:', x))
    tag_html = f'<span class="tag">{esc(t)}</span> ' if t else ''
    items.append(f'''<li class="row{' hour' if hour else ''}">
  <div class="meta"><span class="num">{i:02d}</span><span class="time">{fmt(s)} – {fmt(e)}</span><span class="dur">max. {f'{e - s:.1f}'.replace('.', ',')} s</span></div>
  <div class="txt" data-copy="{esc(line(t, x))}">{tag_html}{esc(x)}</div>
  <button class="cp" type="button">Kopieren</button>
</li>''')
all_text = '\n'.join(line(t, x) for _, _, t, x in rows)
page = f'''<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>ElevenLabs Voiceover</title>
<style>
:root {{ --bg:#f6f6f4; --card:#ffffff; --ink:#16171a; --mute:#6b6e75; --line:#e3e3df; --accent:#d81b22; --tag:#7a4dff; --tagbg:#efe9ff; --hour:#fff4f4; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --bg:#0f1012; --card:#18191c; --ink:#f1f1f2; --mute:#9a9da4; --line:#2a2c31; --accent:#ff4a4f; --tag:#b9a2ff; --tagbg:#2a2342; --hour:#221517; }} }}
:root[data-theme="dark"] {{ --bg:#0f1012; --card:#18191c; --ink:#f1f1f2; --mute:#9a9da4; --line:#2a2c31; --accent:#ff4a4f; --tag:#b9a2ff; --tagbg:#2a2342; --hour:#221517; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; background:var(--bg); color:var(--ink); font:16px/1.45 system-ui,-apple-system,Segoe UI,Roboto,sans-serif; }}
main {{ max-width:760px; margin:0 auto; padding:24px 16px 64px; }}
h1 {{ font-size:26px; margin:0 0 4px; letter-spacing:-.01em; }}
.sub {{ color:var(--mute); margin:0 0 20px; }}
.box {{ background:var(--card); border:1px solid var(--line); border-radius:14px; padding:16px; margin-bottom:18px; }}
.box h2 {{ font-size:15px; text-transform:uppercase; letter-spacing:.06em; color:var(--mute); margin:0 0 10px; }}
.box ol {{ margin:0; padding-left:20px; }} .box li {{ margin:4px 0; }}
pre {{ white-space:pre-wrap; word-break:break-word; background:var(--bg); border:1px solid var(--line); border-radius:10px; padding:12px; margin:0 0 10px; font:14px/1.5 ui-monospace,Menlo,Consolas,monospace; max-height:260px; overflow:auto; user-select:all; -webkit-user-select:all; }}
ul.rows {{ list-style:none; margin:0; padding:0; display:grid; gap:10px; }}
.row {{ background:var(--card); border:1px solid var(--line); border-radius:14px; padding:12px 14px; display:grid; grid-template-columns:1fr auto; gap:6px 12px; align-items:center; }}
.row.hour {{ background:var(--hour); border-color:color-mix(in srgb, var(--accent) 35%, var(--line)); }}
.meta {{ grid-column:1 / -1; display:flex; gap:10px; align-items:baseline; font-size:13px; color:var(--mute); font-variant-numeric:tabular-nums; }}
.num {{ font-weight:700; color:var(--accent); }} .time {{ font-weight:600; color:var(--ink); }}
.txt {{ font-size:17px; user-select:all; -webkit-user-select:all; }}
.tag {{ color:var(--tag); background:var(--tagbg); border-radius:6px; padding:1px 6px; font-family:ui-monospace,Menlo,Consolas,monospace; font-size:14px; }}
button {{ font:600 14px system-ui,sans-serif; border:0; border-radius:10px; padding:9px 14px; background:var(--ink); color:var(--bg); cursor:pointer; white-space:nowrap; }}
button.done {{ background:#1f9d55; color:#fff; }}
.tip {{ color:var(--mute); font-size:14px; margin-top:18px; }}
</style></head>
<body><main>
<h1>ElevenLabs Voiceover</h1>
<p class="sub">72 Stunden ohne Strom · {len(rows)} Sätze · jedes Wort identisch mit den Untertiteln im Video</p>

<section class="box">
<h2>So geht's</h2>
<ol>
<li>In ElevenLabs das Modell <b>Eleven v3</b> wählen. Nur dort funktionieren die <span class="tag">[Tags]</span>.</li>
<li>Stabilität auf <b>Creative</b> oder <b>Natural</b> stellen, dann setzt die Stimme die Tags stärker um.</li>
<li>Entweder alles auf einmal generieren (Block unten) oder jeden Satz einzeln und ihn an seine Startzeit legen.</li>
<li>„max. X s“ ist die Zeit bis zum nächsten Satz. Ist ein Satz länger, die Geschwindigkeit etwas erhöhen.</li>
</ol>
</section>

<section class="box">
<h2>Alles auf einmal</h2>
<pre id="all">{esc(all_text)}</pre>
<button class="cp" type="button" data-target="all">Alles kopieren</button>
</section>

<ul class="rows">
{chr(10).join(items)}
</ul>
<p class="tip">Die Tags sind auf Englisch, weil ElevenLabs sie so am zuverlässigsten erkennt. Gesprochen wird trotzdem nur der deutsche Text. Klingt ein Tag komisch, einfach neu generieren oder den Tag löschen.</p>
</main>
<script>
function copyText(t, btn) {{
  const ok = () => {{ const o = btn.textContent; btn.textContent = 'Kopiert ✓'; btn.classList.add('done'); setTimeout(() => {{ btn.textContent = o; btn.classList.remove('done'); }}, 1400); }};
  const fallback = () => {{ const ta = document.createElement('textarea'); ta.value = t; ta.style.position = 'fixed'; ta.style.opacity = '0'; document.body.appendChild(ta); ta.select(); try {{ document.execCommand('copy'); ok(); }} catch (e) {{}} ta.remove(); }};
  try {{ navigator.clipboard.writeText(t).then(ok, fallback); }} catch (e) {{ fallback(); }}
}}
document.querySelectorAll('button.cp').forEach((b) => b.addEventListener('click', () => {{
  const t = b.dataset.target ? document.getElementById(b.dataset.target).textContent : b.parentElement.querySelector('.txt').dataset.copy;
  copyText(t, b);
}}));
</script>
</body></html>'''
open('out/ElevenLabs_Voiceover.html', 'w', encoding='utf-8').write(page)
komp = []
for s_, e_, t_, x_ in rows:
    komp.append(f'[{fmt(s_)} – {fmt(e_)}] {line(t_, x_)}')
    if x_.startswith('Und jetzt die Frage'):
        komp.append(f'[{fmt(e_)} – {fmt(groups[[g["t"] for g in groups].index(s_) + 1]["t"])}] (Pause – nichts sprechen)')
open('out/ElevenLabs_Komplett.txt', 'w', encoding='utf-8').write('\n'.join(komp) + '\n')
print('wrote out/ElevenLabs_Voiceover.html + .txt + Komplett.txt')
