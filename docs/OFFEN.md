# Abhakliste – Wünsche vs. Stand (v0.5)

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
- ⬜ Kapitel 2–4 (Staumauer, Kapelle, Mine), Offenbarungen 2+3, Enden, Neues Spiel+
- ⬜ Rätsel: Tonband-Rekonstruktion (Kap. 3), Sicherheitsschleuse
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
- ⬜ Staumauer, See, Kirche, Mine, Fabrikruine · zweite Überlebenskarte

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

## Nur du kannst
- 👤 In Studio testen und Output-Meldungen schicken
- 👤 Sounds/Badges/Gamepass/Places anlegen, Voice-Chat aktivieren, Altersfreigabe-Fragebogen
- 👤 Name: SILENT RELAY oder SILENT RELAY?
