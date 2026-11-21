# SILENT RELAY

> Früherer Arbeitstitel: FREQUENCY ZERO. Interne Kürzel (`FZ_…`) und DataStore-Namen bleiben absichtlich unverändert, damit keine Spielstände verloren gehen.

Natives Roblox-Erlebnis (Roblox Studio + Luau), veröffentlicht auf Roblox und spielbar in der Roblox-App auf PC, Smartphone, Tablet und Konsole. Psychologisches Koop-Horrorspiel für 1–4 Spieler.

> Kein eigenständiges Handyspiel, keine Web-App, kein Unity: Der gesamte Code besteht aus Roblox-Scripts, LocalScripts und ModuleScripts für die echten Roblox-Services. (`index.html` im Repo-Root stammt aus dem ursprünglichen Repository und gehört nicht zum Spiel.)
Design, Story und Roadmap: [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

**Stand v0.1 – Fundament (Phase 1):** Sprachsystem (DE/EN/ES/FR/PT-BR), Sprachauswahl beim ersten Start, Speicherstände mit Session-Lock, Einstellungen, Cross-Platform-Eingabe, Interaktionssystem, Menüs mit Controller-Navigation, HUD (Untertitel, Ziele, Dokumente), Taschenlampe, Sprint mit Ausdauer, Codes, Admin-Autorisierung, Leistungsanzeige und ein Greybox-Testgelände mit dem Spielanfang (Ankunftsfunkspruch → Fax → Relais).

---

## Voraussetzung

Roblox Studio läuft nur auf **Windows oder macOS**. Entwickeln und Veröffentlichen geht nicht am Smartphone. Spielen und Testen auf dem Handy geht danach ganz normal über die Roblox-App.

## Installation A – fertige Place-Datei (am einfachsten)

1. [`build/SilentRelay.rbxlx`](build/SilentRelay.rbxlx) auf den PC/Mac herunterladen.
2. Roblox Studio → **Datei → Öffnen** (File → Open from File) → die Datei wählen.
3. **Play** drücken. Das Testgelände wird beim Start automatisch gebaut.
4. Zum Veröffentlichen: **Datei → Auf Roblox veröffentlichen**, danach die einmaligen Einstellungen unten setzen.

Die Datei wird aus `src/` mit Rojo 7.4.4 erzeugt (`rojo build default.project.json -o build/SilentRelay.rbxlx`). Ohne Rojo liefert `python3 tools/build_place.py` denselben Explorer-Baum (gegen Rojo geprüft: 62 Objekte, alle 44 Skripte zeichengleich). Wenn du in Studio direkt etwas änderst, gilt ab dann die Studio-Version – für eine weitere Zusammenarbeit über dieses Repository ist Weg B besser.

## Installation B – Rojo (für die laufende Entwicklung)

1. [Rojo](https://rojo.space) 7.4 oder neuer installieren (CLI + Studio-Plugin).
2. Im Repository-Ordner: `rojo serve`
3. Roblox Studio → neue **Baseplate** öffnen → Rojo-Plugin → **Connect**.
4. Die Standard-Baseplate (`Workspace.Baseplate`) löschen – das Testgelände wird beim Start per Skript gebaut.

Alternativ ohne Live-Sync: `rojo build -o FrequencyZero.rbxlx` und die Datei in Studio öffnen.

### Explorer-Struktur nach dem Sync

```
ReplicatedFirst
  Boot                      (LocalScript)  Logo-Bootscreen, sprachneutral
ReplicatedStorage
  Shared                    (Folder)
    Config, Net, Signal, SessionState      (ModuleScripts)
    Localization            (ModuleScript) + Languages/{de,en,es,fr,pt_br}
ServerScriptService
  Server                    (Folder)
    Main                    (Script)       Server-Bootstrap
    AdminConfig             (ModuleScript)
    Services/…              DataService, SettingsService, AdminService, CodeService,
                            InteractionService, StoryService, FlashlightService, GameFlowService
    Chapters/Chapter1, Dev/Greybox, Util/RateLimiter
ServerStorage
  Secrets/Codes             (ModuleScript) nie beim Client
StarterPlayer               CameraMode = LockFirstPerson, WalkSpeed 10
  StarterPlayerScripts/Client
    Main                    (LocalScript)  Client-Bootstrap
    Controllers/…           Input, Settings, Graphics, Movement, Flashlight, WorldText
    UI/…                    Theme, Components, Router, Hud, DebugOverlay, Screens/…
```

## Was funktioniert – und was noch einzurichten ist

| Bereich | Status |
|---|---|
| Projektstruktur: 84 Objekte, alle Scripts/LocalScripts/ModuleScripts in den richtigen Services | ✅ in der Place-Datei |
| **Karte „Relaisanlage 07“** nach deinem Grundriss (Sektoren A–E, Zentralkern + Radom, Kontrollraum, Hof, Antenne, Zaun, Pförtnerloge, Wald) | ✅ wird beim Start gebaut |
| **Kapitel-1-Ablauf**: Fax → Kontrollraum → 3 Sicherungen (zufällig verteilt) → Prognose brechen → Relais B → Zentralkern → Antenne; wiederholbar | ✅ |
| **Endlos-Überleben „Nachtschicht“**: wechselnde Aufgaben, Ereignisse, steigende Schwierigkeit, 2. Kreatur ab Schicht 6, freiwilliger Ausstieg, Signalmarken, globale Bestenliste | ✅ |
| **Spielen-Menü** (Story-Kapitel + Überlebenskarten aus `Shared/Content.luau`), „Neuigkeiten“-Übersicht, dezente NEU-Markierungen | ✅ |
| **Spielstand-Versionen + Migration** (v1 → v2 automatisch, Schutz vor alten Servern) | ✅ – siehe `docs/UPDATES.md` |
| Mehrere Places + Teleports | ✅ vorbereitet – aktiv, sobald Place-IDs in `Content.Places` stehen |
| Kapitel 2–4, Überlebenskarte „Staumauer 3“ | ⏳ im Menü als „In Entwicklung“ sichtbar |
| **v0.4:** Team-Entscheidungen, Prognosen, Notstrom 2 von 3, HorrorDirector, Hinweise, Geisterprotokolle + Archiv, Titel, Badges, Inventar, Einstellungs-Kategorien + Lautstärke, Spannungsmusik, eigener Prompt, private Sitzungen, Rejoin, Owner-Tests | ✅ – vollständige Abhakliste: `docs/OFFEN.md` |
| **Kreatur-KI** (hört, sieht, sucht, jagt, Lüftungsschächte, Licht blendet) mit Platzhalter-Monster und prozeduraler Animation | ✅ – dein Monster: siehe `docs/CREATURE.md` |
| **Proximity-Voice + Funkgerät** (Push-to-talk, Mikro stumm/frei, Teammitglieder stummschalten, leiser + mehr Rauschen mit Entfernung) | ✅ – braucht Voice-Chat-berechtigte Konten |
| Gesundheit, am Boden liegen, Aufhelfen, Checkpoints | ✅ |
| **Shop** mit Techniker-, Observer-, Sanitäter-Set, Taschenlampen-Upgrade, Funkgerät-Designs | ✅ (nur Signalmarken) |
| Sprache (5), Menüs, Einstellungen, Codes, Wartungsmenü inkl. **Als Kreatur spielen** | ✅ |
| **28 eigene Sounds** in `assets/audio/` | ⚙️ einmal hochladen und die IDs in `Shared/Assets.luau` eintragen (bis dahin bleibt das Spiel still, ohne Fehler) |
| Alles oben | ⚠️ geschrieben und offline geprüft, **noch nicht in Studio ausgeführt** |
| Echte 3D-Modelle (Meshes), Animationen für dein Monster, Kapitel 2–4 | ⏳ folgt / kommt von dir |

### Steuerung

| Aktion | PC | Controller | Touch |
|---|---|---|---|
| Interagieren | E | X / □ | Antippen |
| Rennen | Shift (halten) | L3 (umschalten) | „Rennen“ |
| Taschenlampe (blendet die Kreatur) | F | R1 / RB | „Licht“ |
| Funk senden | R (halten oder umschalten, Einstellungen) | L1 / LB | „Funk“ |
| Mikrofon stumm / frei | M | Steuerkreuz links | „Mikro“ |
| Nachtsicht (Observer-Set) | N | Steuerkreuz oben | „Nacht“ |
| Menü | P | View / Share | „II“ |

### Sounds hochladen (einmalig, ca. 10 Minuten)

1. Creator Hub → Development Items → Audio → die Dateien aus `assets/audio/*.ogg` hochladen. Alle sind selbst synthetisiert, es gibt also keine Lizenzprobleme.
2. Die IDs in `src/ReplicatedStorage/Shared/Assets.luau` eintragen, z. B. `radio_static_loop = "rbxassetid://123456"`.
3. Neu bauen (`rojo build …`) bzw. in Studio im ModuleScript `ReplicatedStorage/Shared/Assets` direkt eintragen.

### Einmalige Studio-Einstellungen (nicht per Skript setzbar)

| Wo | Einstellung | Warum |
|---|---|---|
| Datei → Auf Roblox veröffentlichen | einmal veröffentlichen | DataStores gibt es nur für veröffentlichte Spiele |
| Game Settings → Security | **Enable Studio Access to API Services** an | Speicherstände in Studio testen (sonst Session-Modus mit Hinweis) |
| Game Settings → Basic Info / Places | **Max Players = 4** | 1 Server = 1 Team |
| Game Settings → Communication | **Microphone (Voice Chat) an** | Proximity-Voice und Funk. `VoiceChatService.UseAudioApi = Enabled` und `EnableDefaultVoice = false` sind schon in der Datei gesetzt (Future-Licht ebenfalls) |
| ServerStorage → Attribute | String-Attribut **`FZ_AdminGesture`** (min. 6 Zeichen, nur dir bekannt) | Geheime Zugangsgeste für das Wartungsmenü. Wird absichtlich *nicht* eingecheckt. |
| Creator Dashboard → Localization | Automatische Übersetzung für unsere Sprachen nicht nötig | Alle eigenen Texte haben `AutoLocalize = false` |

Adminrechte: Besitzer des Spiels (User) bzw. Gruppenrang ≥ 254 sind automatisch berechtigt; weitere Entwickler in `AdminConfig.UserIds`. In Studio ist jeder Tester berechtigt (`AllowAllInStudio`). **Die Geste allein gibt nie Rechte.**

---

## Testen

### Automatische Checks (ohne Studio)

```
python3 tools/check_localization.py   # alle Sprachen vollständig, Platzhalter identisch, alle im Code genutzten Schlüssel existieren
python3 tools/check_luau_blocks.py    # Blockstruktur (function/if/do … end, Klammern) aller .luau-Dateien
python3 tools/build_place.py          # erzeugt build/SilentRelay.rbxlx (ohne Rojo)
```

Das ersetzt **keinen** Studio-Test: Typfehler und API-Fehler findet nur Studio bzw. `luau-analyze`.

### Manuelle Tests in Studio (Play / Start Server mit 2–4 Spielern)

| # | Test | Erwartet |
|---|---|---|
| 1 | Erster Start (neuer Spieler / Save löschen) | Nur Logo, dann Sprachauswahl; Studio-Sprache ist vorausgewählt und als „Vorschlag“ markiert. Kein englischer Text blitzt vorher auf. |
| 2 | Sprache wählen, Play stoppen, neu starten | Sprachauswahl erscheint **nicht** mehr, Hauptmenü sofort in der gewählten Sprache. |
| 3 | Einstellungen → Sprache wechseln | Alle sichtbaren Texte (Menü, Schilder in der Welt, Prompt-Texte, offene Untertitel) wechseln im selben Frame. |
| 4 | Spielen | Spawn am Tor, Funkspruch-Untertitel, nach ca. 14 s Ziel „Sieh in der Pförtnerloge nach“. |
| 5 | Fax mit E / X (Controller) / Antippen (Device-Emulator) | Dokument „Arbeitsauftrag 0214“ mit morgigem Datum im Sprachformat; nach ~3 s Relais „Nicht antworten. Noch nicht.“; neues Ziel bei **allen** Spielern. |
| 6 | Zwei Clients mit verschiedenen Sprachen | Gleiche Szene, jeder liest Schild/Notiz/Untertitel in seiner Sprache. |
| 7 | F / RB / „Licht“ | Taschenlampe; der zweite Client sieht den Lichtkegel des ersten. |
| 8 | Shift halten / L3 / „Rennen“ | Sprint ~6 s, dünne Ausdauerlinie, danach Erschöpfung bis 30 %. |
| 9 | P / View-Taste / „II“ | Spielmenü; dieselbe Taste oder B schließt es. Welt läuft weiter. |
| 10 | Extras → `signal-017` | „Signal empfangen. +25“; zweiter Versuch: „bereits empfangen“; Stand bleibt nach Neustart (API-Zugriff an). |
| 11 | Extras → falscher Code ×6 schnell | Ab dem 6. Versuch „Zu viele Versuche“. |
| 12 | Extras → eigene Geste (`FZ_AdminGesture`) | „Wartungszugang gewährt.“, Eintrag „Wartung“ erscheint; dort Leistungsanzeige (FPS, Ping, Speicher, Profil). Mit `AllowAllInStudio = false` und fremder UserId: nur „Auf dieser Frequenz ist nichts.“ |
| 13 | Controller only | Jeder Menüpunkt erreichbar, B = zurück, D-Pad links/rechts ändert Einstellungen. Keine Maus nötig. |
| 14 | Device-Emulator iPhone quer (Studio: Test → Device) | Menü passt ohne Abschneiden; Touch-Buttons nur im Spiel sichtbar; Buttons ≥ ca. 43 pt hoch. |
| 15 | Output-Fenster | Keine `[FZ-Loc] Missing translation`-Warnungen; `[FZ] Server ready`. |
| 16 | Kontrollraum-Terminal | Ziel „Finde Sicherungen (0/3)“, 3 leuchtende Sicherungen in 3 verschiedenen Sektoren (bei jedem Neustart anders). |
| 17 | 1. Sicherung | Relais: „Jetzt ist es wach. Geht. Rennt nicht.“ – Kreatur erscheint in Sektor C und patrouilliert. |
| 18 | 2. Sicherung → innerhalb 30 s Schalter in Sektor A halten | „Ihr… habt ihn gehalten.“ + Belohnung. Ohne Schalter: Licht in A geht aus, die Kreatur kommt nachsehen. |
| 19 | Vor der Kreatur sprinten / still stehen / mit F anleuchten | Sprinten lockt sie an, Stillstand nicht; Licht ins Gesicht: sie hält sich die Arme vors Gesicht und zieht sich zurück. |
| 20 | Drei Treffer kassieren (2 Spieler) | „Du bist am Boden“, kriechen; Teammitglied hält „Aufhelfen“ → zurück mit 35 HP. Solo: zurück zum Checkpoint. |
| 21 | Funk mit 2 Voice-Konten (veröffentlichtes Spiel) | R halten → Partner hört dich gefiltert über Funk; je weiter weg, desto leiser und verrauschter. M = stumm. In „Team“ Spieler antippen = für dich stummschalten. |
| 22 | Shop | Ohne genug Signalmarken: „Noch nicht genug“. Wartung → „100 Testmarken“ mehrfach → Sanitäter-Set freischalten (zweimal tippen = bestätigen) → ausrüsten. |
| 23 | Wartung → Als Kreatur spielen | Third-Person im Monster, F = Angriff (nur Studio/private Server), „Zurück zu meinem Charakter“. |

Bitte Ergebnisse (v. a. Fehlermeldungen aus dem Output-Fenster) zurückmelden – daraus wird der nächste Schritt.

---

## Benötigte Assets (noch nicht enthalten)

Keine Asset-IDs sind erfunden; alles hier fehlt bewusst und wird über Creator Store / eigene Produktion ergänzt:

- **Audio:** Funkrauschen (Loop, 3 Intensitäten), Fax-Druck, Schritte je Untergrund (Beton, Linoleum, Metall, Asphalt nass), Türmechanik, Generatorbrummen, Regen außen/innen, Lauscher-Signatur (Knacken, Stotter-Statik), UI-Klick/-Fokus (leise), englische Sprachaufnahmen für alle `RADIO_*`-Zeilen (Sprecher, keine KI-Stimmen).
- **Modelle:** Funkgerät-Viewmodel mit Rig, Taschenlampe, Lauscher (Rig + Animationen: Idle, Lauschen, Gehen, Stotter-Sprung, Jagd), Fax, Konsolen, Monitore, Architektur-Kit Beton/Stahl.
- **Texturen:** SurfaceAppearance-Sets für Hero-Objekte, MaterialVariants für Beton/Linoleum/Lack.

## Auf echten Geräten testen

1. Veröffentlichen (privat lassen).
2. Am Handy/Tablet/Konsole in der Roblox-App unter „Erstellungen“ bzw. über den Spiellink starten.
3. Wartungsmenü → Leistungsanzeige einschalten und FPS/Ping notieren.
