# FREQUENCY ZERO

Psychologisches Koop-Horrorspiel für Roblox (1–4 Spieler, PC / Mobile / Konsole).
Design, Story und Roadmap: [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

**Stand v0.1 – Fundament (Phase 1):** Sprachsystem (DE/EN/ES/FR/PT-BR), Sprachauswahl beim ersten Start, Speicherstände mit Session-Lock, Einstellungen, Cross-Platform-Eingabe, Interaktionssystem, Menüs mit Controller-Navigation, HUD (Untertitel, Ziele, Dokumente), Taschenlampe, Sprint mit Ausdauer, Codes, Admin-Autorisierung, Leistungsanzeige und ein Greybox-Testgelände mit dem Spielanfang (Ankunftsfunkspruch → Fax → Relais).

---

## Installation (Rojo, empfohlen)

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

### Einmalige Studio-Einstellungen (nicht per Skript setzbar)

| Wo | Einstellung | Warum |
|---|---|---|
| Game Settings → Security | **Enable Studio Access to API Services** an | Speicherstände in Studio testen (sonst Session-Modus mit Hinweis) |
| Game Settings → Basic Info / Places | **Max Players = 4** | 1 Server = 1 Team |
| Lighting | **Technology = Future** | Schatten der Punkt-/Spotlights |
| Workspace | **StreamingEnabled = true** | Performance auf Mobilgeräten |
| ServerStorage → Attribute | String-Attribut **`FZ_AdminGesture`** (min. 6 Zeichen, nur dir bekannt) | Geheime Zugangsgeste für das Wartungsmenü. Wird absichtlich *nicht* eingecheckt. |
| Creator Dashboard → Localization | Automatische Übersetzung für unsere Sprachen nicht nötig | Alle eigenen Texte haben `AutoLocalize = false` |

Adminrechte: Besitzer des Spiels (User) bzw. Gruppenrang ≥ 254 sind automatisch berechtigt; weitere Entwickler in `AdminConfig.UserIds`. In Studio ist jeder Tester berechtigt (`AllowAllInStudio`). **Die Geste allein gibt nie Rechte.**

---

## Testen

### Automatische Checks (ohne Studio)

```
python3 tools/check_localization.py   # alle Sprachen vollständig, Platzhalter identisch, alle im Code genutzten Schlüssel existieren
python3 tools/check_luau_blocks.py    # Blockstruktur (function/if/do … end, Klammern) aller .luau-Dateien
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
| 14 | Device-Emulator iPhone quer | Menü passt ohne Abschneiden; Touch-Buttons nur im Spiel sichtbar; Buttons ≥ ca. 43 pt hoch. |
| 15 | Output-Fenster | Keine `[FZ-Loc] Missing translation`-Warnungen; `[FZ] Server ready`. |

Bitte Ergebnisse (v. a. Fehlermeldungen aus dem Output-Fenster) zurückmelden – daraus wird der nächste Schritt.

---

## Benötigte Assets (noch nicht enthalten)

Keine Asset-IDs sind erfunden; alles hier fehlt bewusst und wird über Creator Store / eigene Produktion ergänzt:

- **Audio:** Funkrauschen (Loop, 3 Intensitäten), Fax-Druck, Schritte je Untergrund (Beton, Linoleum, Metall, Asphalt nass), Türmechanik, Generatorbrummen, Regen außen/innen, Lauscher-Signatur (Knacken, Stotter-Statik), UI-Klick/-Fokus (leise), englische Sprachaufnahmen für alle `RADIO_*`-Zeilen (Sprecher, keine KI-Stimmen).
- **Modelle:** Funkgerät-Viewmodel mit Rig, Taschenlampe, Lauscher (Rig + Animationen: Idle, Lauschen, Gehen, Stotter-Sprung, Jagd), Fax, Konsolen, Monitore, Architektur-Kit Beton/Stahl.
- **Texturen:** SurfaceAppearance-Sets für Hero-Objekte, MaterialVariants für Beton/Linoleum/Lack.
