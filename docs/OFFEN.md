# Abhakliste – Wünsche vs. Stand (v0.6 · Spielversion 0.4.0)

Legende: ✅ eingebaut · 🟡 teilweise · ⬜ offen · 👤 braucht dich (Assets, IDs, Studio)

## Gameplay & Story
- ✅ Allgemeines Aufgaben-System nach deinem Loop (Entdecken → Entscheiden → Handeln → Konsequenzen): Ziele, Prognosen, Team-Entscheidungen, Hinweise
- ✅ Prognosen als System (Kapitel 1: Licht in A, Generator E · Überleben: Stromausfall-Prognose)
- ✅ Story-Entscheidungen mit Konsequenzen („Antworten oder Schweigen“ → andere Funksprüche, frühere Kreatur, anderes Ende-Funkspruch, gespeichert für spätere Kapitel)
- ✅ Notstrom 2 von 3 (Kameras / Flurlicht / Lüftung) mit echten Auswirkungen
- ✅ HorrorDirector: Gestalt am Gangende, Schritte hinter dir, Flackern, Überwachungsbild 20 s in der Zukunft (nur einer sieht die Gestalt), Name gerufen, Tür fällt zu – mit Abständen gegen Gewöhnung
- ✅ Getrennte Wahrnehmung (Überwachungsbild, Namensruf)
- ✅ Optionale Hinweise beim Feststecken
- ✅ Kalender/Kaffee + 4 Geisterprotokolle, Archiv
- 🟡 Reaktive Umgebung: Strom, Türen, Licht ✅ · Aufzüge/Lautsprecher ⬜
- ✅ Kapitel 2 „Die falsche Stimme“ (Staumauer im Sturm): persönliche Prognose mit Spielernamen, gebrochene Prognosen verändern den Weg (Galerie geflutet → Rampe außen), aktiv jagender Lauscher, Entscheidung „Wem glaubt ihr?“, Uplink im Antennenhof halten
- ✅ Kapitel 3 „Das Protokoll“ (Kapelle + Archiv im Hügel): Tonband-Rekonstruktion (hören + ordnen, keine Codes, zufällig pro Durchlauf), Twist mit eurem Funkgerät-Design, euren Namen und DURCHLAUF 0007, Entscheidung „Rekorder mitnehmen/zerstören“
- ✅ Kapitel 4 „Frequenz Null“ (Mine): Zeitschichten heute ↔ 2009 (Wege nur in einer Schicht offen), alle 4 Prognose-Arten, drei Enden: Antworten · Schweigen · geheime Gegenfrequenz (alle 6 Geisterprotokolle + jede Prognose-Art gebrochen)
- ✅ Neues Spiel+: nach „Antworten“ begrüßt Kapitel 1 euch mit „Ihr seid zurück.“ · Entscheidungen aus Kap. 2/3 ändern Funksprüche in Kap. 4
- ⬜ Sicherheitsschleuse
- ⬜ Funkgerät-Peilmechanik (von dir zurückgestellt)
- ⬜ Rätsel-Skalierung mit Spielerzahl (bisher nur Kreatur-Tempo solo)

## v0.5 (Erweiterungsprompt)
- ✅ HorrorDirector mit Gewichtungen, Abklingzeiten, Seltenheit: Gestalt hinter Glas, Gestalt im leeren Raum, Lautsprecherstimme, Licht im Nebenraum, Schritte hinter dir, Schatten, Monster-Täuschungsgeräusche hinter Wänden, Annäherung im Gang, gedämpfte Stimmen, nur-für-dich-sichtbares Objekt
- ✅ Kreatur-Klangidentität (21 neue Sounds, Varianten, Wand-Dämpfung) · Asset-Liste `docs/SOUND_ASSETS.md`
- ✅ Am Boden / Rettung mit Medkit (4 s, verwundbar, abbrechbar), Ausscheiden + Zuschauen, Solo-Notfallspritze, Erste-Hilfe-Schränke
- ✅ Übernatürliche Fotos (eigener Avatar dort, wo du vor 5 Min. warst · Team vor unerreichtem Ort · Mitspieler im dunklen Gang)
- ✅ DAS ARCHIV als Terminal (Kategorien, gesperrte Akten, Verknüpfungen → Erkenntnisse, Frequenzeingabe)
- ✅ Erfolge (9) mit einmaligen Belohnungen
- ✅ Risiko oder Rettung (Abstimmung, Gleichstand = evakuieren, Einzel-Ausstieg, 75-s-Evakuierung)
- ✅ Community-Belohnung (serverseitig geprüft) · Tutorial `docs/COMMUNITY.md` · 👤 Community-ID eintragen
- ✅ Freundes-Einladungen mit Missbrauchsschutz · 👤 nach Launch testen
- ✅ Erweiterbares Geheimnis-System (erstes Rätsel: „Frequenz Null“) mit globalem Löser-Zähler
- 🟡 Echte Animationen für Knien/Am-Boden (derzeit: Körper abgesenkt + Kamera; Animation-IDs folgen mit Animationen)

## Karten
- 🟡 Relaisanlage 07 (Blockout aus Bauteilen) · 👤 deine Kartenteile
- ✅ Staumauer 3 (Tal, Mannschaftstrakt, Turbinenhalle, Galerie in der Mauer, Schrägstollen, Serpentinen-Rampe, Krone mit Antennenhof über dem Stausee)
- ✅ Kapelle (Friedhof, Glockenturm, Kirchenschiff, Sakristei, Archiv-Bunker im Hügel, versiegelter Operatorraum)
- ✅ Mine (Förderturm, Maschinenhaus, Stollennetz mit Holzausbau, Pumpen-/Schachtraum, verschütteter Gang, Rundweg, Echo-Array-Kaverne)
- ✅ Zweite Überlebenskarte: Staumauer 3 – Schleusentor (Überleben ist jetzt kartenunabhängig über Profile)
- ⬜ Fabrikruine

## Kreatur, Modelle, Animationen
- ✅ KI, Platzhalter-Kreatur, prozedurale Animation, mehrere Kreaturen gleichzeitig
- 👤 dein Monster-Modell (Einbau vorbereitet: `docs/CREATURE.md`)
- ⬜ weitere Kreaturtypen · ⬜ Ego-Arme/Taschenlampen-Modell · 👤 echte 3D-Modelle & Animationen

## Sound
- ✅ 31 eigene Sounds inkl. Menü-/Spannungsmusik · ✅ Spannungsebenen nach Kreatur-Nähe · ✅ Raumhall · ✅ UI-Klicks · ✅ Ducking
- 👤 Sounds hochladen + IDs in `Shared/Assets.luau`
- ⬜ Sprachaufnahmen (Sprecher) + Audiosprache-Einstellung

## Menüs, Steuerung, HUD
- ✅ Einstellungen in 5 Kategorien, 6 Lautstärkeregler, Steuerungsübersicht pro Gerät, Flackern reduzieren, Gesundheit immer zeigen
- ✅ Eigener Interaktions-Prompt (alle Geräte, großes Touch-Ziel)
- ✅ Hotbar mit Verband/Spritze · ✅ Prognose-Countdown · ✅ Entscheidungs-Panel

## Shop, Belohnungen
- ✅ Sanitäter: Heilgegenstände + Bonus · ✅ Techniker: +1 Platz · ✅ Taschenlampen-Farben · ✅ Titel · ✅ Badges (👤 IDs)
- ⬜ Lobby-Kosmetik, Charakter-Outfits (👤 Assets) · 👤 Gamepass/Developer-Product-IDs

## Multiplayer & Technik
- ✅ Private Sitzung mit Einladung · ✅ Zurück zum Team nach Verbindungsabbruch · ✅ Speed-Schutz · ✅ Analytics · ✅ Grafik „Automatisch“ nach FPS
- 🟡 Ganzes Team gemeinsam in andere Places teleportieren (privat ✅, Inhalts-Places nur einzeln)
- ✅ Owner-Tools: Monster per Blick, Checkpoints, Prognose-/Licht-/Schreck-/Soundtests, dauerhaftes Protokoll

## Qualitätssicherung (läuft ohne Studio)
- ✅ `lune run tools/check_syntax.luau` – echter Luau-Compiler über alle Skripte
- ✅ `lune run tools/ui_smoke.luau` – alle Menüs + HUD gegen die Roblox-API (auch Handy-Größe)
- ✅ `lune run tools/server_smoke.luau` – spielt Kapitel 1–4 (mehrere Entscheidungswege), Überleben auf beiden Karten und den Kartenwechsel komplett durch
- ✅ `lune run tools/bake_map.luau` – baut alle 4 Karten headless und legt sie in die Datei

## Nur du kannst
- 👤 In Studio testen und Output-Meldungen schicken
- 👤 Sounds/Badges/Gamepass/Places anlegen, Voice-Chat aktivieren, Altersfreigabe-Fragebogen
- 👤 Name: SILENT RELAY oder SILENT RELAY?
