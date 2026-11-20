# Video-Drehplan – Kaspar Damast-Duo 🎬

**Ziel:** Echte, ungeschönte Clips, die in 3 Sekunden zeigen, wie scharf das Messer ist.
Kein Studio nötig, das Handy reicht. Gerade das Ungeschliffene wirkt echt und eben **nicht** nach KI.

## Grundregeln (gelten für alle Clips)

| | |
|---|---|
| **Format** | Hochformat 9:16, 4K oder 1080p, 30 fps |
| **Länge** | 6–10 Sekunden. Der Schnitt passiert in den **ersten 2 Sekunden** |
| **Licht** | Tageslicht vom Fenster, seitlich. Kein Deckenlicht von oben, das spiegelt auf der Klinge |
| **Untergrund** | Dunkles Holzbrett. Hintergrund ruhig: schwarze Arbeitsplatte oder dunkles Tuch |
| **Ton** | Unbedingt mit Ton aufnehmen! Das Schnittgeräusch ist Gold wert (ASMR-Effekt). Ruhige Umgebung, keine Musik |
| **Kamera** | Handy auf Stativ oder abgestützt, Fokus antippen und halten (iPhone: lange drücken = AE/AF-Sperre) |
| **Hände** | Echte Hände, gern mit Ring oder Tattoo, Fingernägel sauber. Das macht es menschlich |
| **Vorher** | Klinge mit Mikrofasertuch polieren, keine Fingerabdrücke |

## Die 5 Clips (Reihenfolge = Priorität)

### 1. Tomaten-Test ⭐ (wichtigster Clip)
- **Einstellung:** seitlich auf Brett-Höhe, Nahaufnahme
- **Aktion:** reife Tomate, Kochmesser **ohne Druck** einmal ziehen, die Scheibe kippt um
- **Bonus:** danach eine hauchdünne Scheibe gegen das Licht halten
- **Untertitel:** `Reife Tomate.` → `Kein Druck. *Einfach durch.*` → `Hauchdünn.`

### 2. Zwiebel würfeln
- **Einstellung:** von oben (Handy über dem Brett)
- **Aktion:** halbe Zwiebel zügig würfeln. Zeitraffer 2× ist okay, dann aber **im Untertitel sagen**
- **Untertitel:** `Eine Zwiebel.` → `Würfeln wie im *Restaurant.*`

### 3. Auspacken / Unboxing
- **Einstellung:** von schräg oben, Box im Bild
- **Aktion:** Deckel ab, Kochmesser langsam rausziehen und drehen, sodass Licht über das Damastmuster wandert
- **Untertitel:** `Ausgepackt.` → `Das Geschenk, das man *jeden Tag* benutzt.`

### 4. Hero-Clip (großes Bild oben, ohne Ton)
- **Einstellung:** quadratisch denken, Messer mittig, dunkler Hintergrund
- **Aktion:** Messer liegt schräg, Kamera fährt langsam an der Klinge entlang (Makro), Licht wandert übers Muster
- **Dateiname:** muss mit `hero` beginnen, z. B. `hero-klinge.mov`

### 5. Papier-Test (optional)
- **Aktion:** Messer schneidet ein senkrecht gehaltenes Blatt Papier sauber durch
- **Untertitel:** `Der Klassiker.` → `*Sauber.* Kein Reißen.`

## ⚠️ Ehrlich bleiben
- Nur echte Schnitte zeigen, nichts mit Effekten „nachschärfen“.
- Zeitraffer, Schnitte im Video oder neu geschliffene Klingen kennzeichnen. Irreführende Produktvideos sind wettbewerbsrechtlich angreifbar.
- Keine Fremdmarken im Bild (andere Messer, Logos).

## So kommen die Clips auf die Seite

```bash
# 1. Originale vom Handy nach assets/video/raw/ kopieren
#    (z. B. 1-tomate.mov, 2-zwiebel.mov, 3-unboxing.mov, hero-klinge.mov)
# 2. Fertig machen – komprimiert, Vorschaubilder, trägt alles in die Config ein:
npm run medien
```

3. Nur noch die **Untertitel** in `shop.config.json` → `media.reels` ergänzen. So sieht ein fertiger Eintrag aus:

```json
"media": {
  "heroVideo": { "src": "/assets/video/hero-klinge.mp4", "poster": "/assets/video/hero-klinge.jpg" },
  "reels": [
    {
      "src": "/assets/video/tomate.mp4",
      "poster": "/assets/video/tomate.jpg",
      "title": "Tomaten-Test",
      "captions": [
        { "t": 0, "text": "Reife Tomate." },
        { "t": 1.6, "text": "Kein Druck. *Einfach durch.*" },
        { "t": 4.5, "text": "Hauchdünn." }
      ]
    }
  ]
}
```

- `t` = Sekunde, ab der der Untertitel erscheint. Text in `*Sternchen*` wird orange hervorgehoben.
- Danach `"showPlaceholders": false` setzen.

**Tipp:** Dieselben Clips direkt als Instagram-Reels und TikToks posten. Dann sehen Leute auf der Seite genau das wieder, was sie hergeführt hat. Dieser Wiedererkennungseffekt steigert die Conversion.
