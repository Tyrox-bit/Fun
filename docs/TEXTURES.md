# Realistische Texturen (Foto-Scans)

Das Spiel bringt **19 fotorealistische PBR-Texturen** mit (`assets/textures/`): echte Foto-Scans
von Poly Haven, Lizenz **CC0** – frei für dein Spiel, auch kommerziell (Credits: `assets/textures/CREDITS.md`).

| Roblox-Material | Textur | wo im Spiel |
|---|---|---|
| Concrete | Betonwand mit Flecken und Rissen | fast alle Wände, Staumauer, Böden |
| Plaster | grauer Putz | gestrichene Wandsockel |
| CeramicTiles | verschmutzte Fliesen | Kantine, Kontrollraum, Operatorraum |
| Metal | zerkratzter, lackierter Stahl | Türen, Konsolen, Generatoren |
| DiamondPlate | Riffelblech | Gitter, Lüftungen, Laufstege |
| CorrodedMetal | Rost | Container, Fässer, Loren |
| Wood / WoodPlanks | abgenutztes Holz / verwitterte Bretter | Tische, Kisten, Bänke |
| Asphalt / Pavement / Pebble | Asphalt, Betonplatten, Kies | Straßen, Staumauer-Krone, Wege |
| Cobblestone / Slate | Bruchsteinmauer, Schieferboden | Kapelle |
| Rock / Ground | Felswand, Waldboden | Mine, Terrain |
| Brick / RoofShingles | Ziegel, Schieferdach | Maschinenhaus, Dächer |
| Fabric / Carpet | Leinen, alter Teppich | Sitze, Archiv |

Jede Textur hat Farbe, Relief (Normal Map), Rauheit (und bei Riffelblech Metall). Roblox legt sie als
**MaterialVariant** über das jeweilige Grundmaterial – damit sind sofort **alle Teile und das Terrain**
auf allen vier Karten texturiert, ohne ein Teil anzufassen.

## Warum du einmal hochladen musst

Roblox zeigt nur Bilder, die in einem Roblox-Account liegen – Skripte dürfen keine Bilder aus dem Internet
laden. Deshalb müssen die 56 Bilder einmal in **deinen** Account. Zwei Wege:

### Weg A – ich mache alles (empfohlen)

1. Öffne **create.roblox.com** → oben rechts Profilmenü → **Open Cloud** → **API Keys** → **Create API Key**.
2. Name: `SilentRelay Textures`. Unter **Access Permissions** die API **Assets** hinzufügen, Rechte **Read** und **Write**.
3. Bei **Accepted IP Addresses** `0.0.0.0/0` eintragen (mein Server hat keine feste IP). Ablaufdatum gern 7 Tage.
4. Speichern, den Schlüssel **nicht** in den Chat kopieren. Sag mir einfach „Key ist fertig“ und nenne deine
   **Roblox-User-ID** (die Zahl in deiner Profil-Adresse `roblox.com/users/<ZAHL>/profile`).
5. Ich frage den Schlüssel über ein sicheres Formular ab, lade alle Bilder hoch, trage die IDs ein und schicke
   dir die fertige Datei. Danach kannst du den Schlüssel löschen.

### Weg B – selbst in Studio

1. Lade `SilentRelay_Texturen.zip` herunter und entpacke es.
2. Studio → **View → Asset Manager** → **Bulk Import** → alle Bilder auswählen.
3. Für jedes Bild: Rechtsklick → **Copy ID** → in `ReplicatedStorage → Shared → Assets → Textures → <Material>`
   bei `color` / `normal` / `roughness` (/ `metalness`) als `"rbxassetid://<ID>"` eintragen.
4. **Play** drücken: `TextureService` legt die Materialien an. Oder schick mir die Liste – dann backe ich sie fest in die Datei, dann sieht man sie auch im Editor.

## Für Entwickler

- `tools/prepare_textures.py download|process` – lädt die Scans neu und bereitet sie auf (AO eingebacken,
  Helligkeit normalisiert, weil Roblox die Textur mit der Teilfarbe multipliziert, echte Größe → `StudsPerTile`).
- `tools/upload_textures.py` – Open-Cloud-Upload, schreibt die IDs in `Shared/Assets.luau`.
- `tools/bake_map.luau` – backt Varianten + Overrides in die Datei (`FZ_TEXTURE_TEST=1` = Formattest mit Platzhalter-IDs).
- Austauschen: anderes Poly-Haven-Asset in `PICK` eintragen, `download` + `process`, neu hochladen.
