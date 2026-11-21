# Offizielle Roblox-Community für SILENT RELAY einrichten

Roblox nennt Gruppen inzwischen **„Communities“**. Technisch ist es dasselbe: Im Code heißt die ID weiterhin `GroupId`.

## 1. Community erstellen
1. Auf roblox.com (Browser, PC oder Handy) einloggen → linkes Menü **Communities** → **Create Community** / „Community erstellen“.
2. Das Erstellen kostet einmalig Robux (derzeit 100 Robux, der aktuelle Betrag steht auf der Seite).
3. Wähle **Öffentlich (jeder kann beitreten)**, wenn die Belohnung sofort nach dem Beitritt funktionieren soll. Bei „Manuelle Freigabe“ zählt ein Spieler erst als Mitglied, wenn du seine Anfrage angenommen hast. Das Spiel kann damit umgehen (siehe unten).

## 2. Name und Logo
Beides gibst du direkt beim Erstellen ein: **Name** („SILENT RELAY“ oder z. B. „Silent Relay Station“), **Beschreibung** und **Emblem/Logo** (quadratisch, mindestens 256 × 256 px). Ändern kannst du alles später unter **Community → ⋯ → Configure Community / Einstellungen**. Logo und Texte werden von Roblox moderiert und sind erst nach der Prüfung sichtbar.

## 3. Community-ID finden
Öffne deine Community im Browser. Die Adresse sieht so aus:
`https://www.roblox.com/communities/`**`12345678`**`/Silent-Relay`
Die Zahl ist die **Community-ID**.

## 4. ID im Spiel hinterlegen
Datei `src/ReplicatedStorage/Shared/Community.luau` öffnen (in Studio: `ReplicatedStorage → Shared → Community`):
```lua
GroupId = 12345678,
```
Speichern und veröffentlichen. Solange `GroupId = 0` ist, bleibt der Community-Eintrag im Extras-Menü versteckt.

## 5. Experience mit der Community verknüpfen (optional)
- **Für die Belohnung nicht nötig.** Das Spiel prüft nur, ob ein Spieler Mitglied ist. Dafür muss die Experience nicht der Community gehören.
- Soll die Experience der Community gehören, z. B. damit mehrere Entwickler mitarbeiten oder Einnahmen an die Gruppe gehen, findest du im Creator Hub bei der Experience **Transfer Ownership** (sofern für dein Konto verfügbar).
- Danach erkennt das Spiel als Besitzer alle mit **Rang ≥ 254** (`ServerScriptService/Server/AdminConfig.luau → MinGroupRank`). Spielstände bleiben erhalten, weil sie an der Experience hängen.
- Optional kannst du die Community auf der Spielseite verlinken (Creator Hub → Experience → Social Links / Community).

## 6. Testen, ob die Belohnung wirklich funktioniert
1. Die ID ist eingetragen und das Spiel veröffentlicht. In Studio zusätzlich: **Game Settings → Security → Enable Studio Access to API Services**.
2. Mit einem Testkonto, das **noch nicht Mitglied** ist: Spielen → Extras → Community → **Mitgliedschaft prüfen**. Erwartet: „Noch keine Mitgliedschaft gefunden“, keine Belohnung.
3. **Community beitreten** antippen (oder auf der Webseite beitreten) → erneut **prüfen**. Erwartet: „Willkommen, Relaisfunker! +350 Signalmarken“, der Titel erscheint im Archiv unter „Titel“.
4. Noch einmal prüfen: „Belohnung bereits erhalten“. Spiel verlassen und neu beitreten: Die Belohnung bleibt einmalig, weil sie im Spielstand gespeichert ist.
5. **Ausstehende Anfrage testen:** Community auf manuelle Freigabe stellen, mit einem zweiten Konto beitreten anfragen → prüfen ergibt „ausstehend/noch kein Mitglied“. Annehmen → prüfen → Belohnung.
6. **Fehlerfall:** Wenn Roblox nicht antwortet, zeigt das Spiel einen Hinweis, und **nichts wird verbraucht**. Der Spieler kann es später erneut versuchen (höchstens etwa alle 10 Sekunden).

## Sicherheit (bereits eingebaut)
- Die Mitgliedschaft wird **nur auf dem Server** geprüft (`Player:IsInGroupAsync`, sonst `IsInGroup`). Der Client kann nichts behaupten.
- Der Anspruch steht im Spielstand (`community.claimed`), und dank Session-Lock ist eine doppelte Einlösung auch über mehrere Server unmöglich.
- „Likes“ oder Favoriten werden nirgends als bestätigt behandelt. Dafür gibt es keine zuverlässige Prüfmöglichkeit, deshalb gibt es auch keine Belohnung dafür.

## Freundes-Einladungen (Referral)
- Der Button „Freunde einladen“ (Team-Menü) nutzt die offizielle Roblox-Einladung und schickt `LaunchData = "ref:<deine UserId>"` mit.
- **Belohnung (je 100 Signalmarken für beide)** gibt es nur, wenn alle Bedingungen erfüllt sind:
  - Der Eingeladene ist **wirklich neu** im Spiel (erste Sitzung).
  - Sein Konto ist mindestens 7 Tage alt.
  - Er erreicht den Kontrollraum in Kapitel 1 oder spielt 15 Minuten.
- Pro eingeladenem Konto gibt es die Belohnung einmal, pro Einladendem höchstens 10 Mal. Ein bloßes Antippen bringt nichts.
- Hinweis: Einladungsdaten werden nur bei echten Roblox-Einladungen übertragen und funktionieren in der Regel erst im **veröffentlichten, öffentlichen** Spiel. Bitte nach dem Launch mit zwei Konten testen.
