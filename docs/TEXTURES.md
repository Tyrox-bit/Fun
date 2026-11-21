# Realistische Texturen (Foto-Scans)

Das Spiel bringt **38 fotorealistische PBR-Texturen** und **6 Schmutz-Decals** mit (`assets/textures/`):
echte Foto-Scans von Poly Haven, Lizenz **CC0** – frei für dein Spiel, auch kommerziell (Credits: `assets/textures/CREDITS.md`).
Die Decals erzeugt `tools/generate_grime.py` selbst (100 % eigen).

**22 Grundmaterialien** (gelten überall, auch fürs Terrain): Beton, Putz, Fliesen, lackierter Stahl, Riffelblech, Rost,
Holz, Dielen, Asphalt, Bruchstein, Schiefer, Fels, Ziegel, Leinen, Teppich, Schieferdach, Kies, Betonplatten,
Waldboden, flechtiger Stein (Grabsteine), Marmor (Altar), Schlamm.

**16 Spezialtexturen für einzelne Bauteile** (`MapDress.Surfaces`):

| Variante | Scan | wo |
|---|---|---|
| ConcreteFloor | abgenutzter Betonboden | Böden |
| DamConcrete | verwitterter Beton | Staumauer, Stützpfeiler |
| CrackedWall | rissiger Beton | Flure in Relais 07, Galerie in der Mauer, Bunker unter der Kapelle |
| Ceiling | Rasterdecke | Innendecken |
| RoofConcrete | geschichteter Beton | Flachdächer, Galeriedecke |
| DoorMetal | rostig lackierter Stahl | Stahltüren und Zargen |
| Machine | grün lackiert, rostig | Generatoren, Turbinen, Pumpe, Trafos |
| Container / Corrugated | Container-Blech, Wellblech | Container, Schuppendach |
| Bark / Timber / DarkWood | Kiefernrinde, grobes Holz, dunkles Holz | Bäume, Grubenausbau, Kirchenbänke |
| OldFloor / ChapelFloor | alte Dielen, Klostersteinboden | Sakristei, Kirchenschiff |
| Rubble / MineFloor | Schutt, steiniger Pfad | Geröll, Stollenboden |

**Schmutz-Decals** (`MapDress.Grime`, ~20 pro Karte): Wasserläufe unter der Decke, Rostfahnen, Schimmel in Ecken,
Ruß, Risse, eingeritzte Strichlisten.

Jede Textur hat Farbe, Relief (Normal Map), Rauheit (Riffelblech auch Metall). Roblox legt sie als **MaterialVariant**
über die Teile – auf allen vier Karten auf einen Schlag.

## Warum du einmal hochladen musst

Roblox zeigt nur Bilder, die in einem Roblox-Account liegen – Skripte dürfen keine Bilder aus dem Internet
laden. Deshalb müssen die 121 Bilder einmal in **deinen** Account. Zwei Wege:

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
2. Studio → **View → Asset Manager** → **Bulk Import** → alle Bilder auswählen (auch den Ordner `Grime`).
3. Für jedes Bild: Rechtsklick → **Copy ID** → in `ReplicatedStorage → Shared → Assets → Textures → <Material>`
   bei `color` / `normal` / `roughness` (/ `metalness`) als `"rbxassetid://<ID>"` eintragen.
4. **Play** drücken: `TextureService` legt die Materialien an. Oder schick mir die Liste – dann backe ich sie fest in die Datei, dann sieht man sie auch im Editor.

## Für Entwickler

- `tools/prepare_textures.py download|process` – lädt die Scans neu und bereitet sie auf (AO eingebacken,
  Helligkeit normalisiert, weil Roblox die Textur mit der Teilfarbe multipliziert, echte Größe → `StudsPerTile`).
- `tools/upload_textures.py` – Open-Cloud-Upload, schreibt die IDs in `Shared/Assets.luau`.
- `tools/bake_map.luau` – backt Varianten + Overrides in die Datei (`FZ_TEXTURE_TEST=1` = Formattest mit Platzhalter-IDs).
- Austauschen: anderes Poly-Haven-Asset in `PICK` eintragen, `download` + `process`, neu hochladen.
