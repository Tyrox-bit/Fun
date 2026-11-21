# Karten-Vertrag – eigene Karte oder eigene Räume einbauen

Die Spielsysteme kennen keine festen Positionen, nur **Tags** und **Attribute**. Deshalb kannst du jeden Teil der Skript-Karte durch deine eigene Studio-Karte ersetzen.

- **Komplett eigene Karte:** Lege dein Modell als `Workspace/FZ_Map` an. Dann wird die Skript-Karte nicht gebaut. Setze die folgenden Tags (Tag Editor bzw. Eigenschaften → Tags) und Attribute.
- **Nur Teile ersetzen:** Lass `FZ_Map` weg und tausche nach dem ersten Start einzelne Räume aus. Am einfachsten geht das so: Play → Explorer → `FZ_RelayStation07` kopieren → Play stoppen → einfügen, als `FZ_Map` umbenennen und dann umbauen.

| Tag | Wofür | Attribute |
|---|---|---|
| `FZ_Interactable` | alles, womit man interagiert | `InteractId` (z. B. `door`, `c1_fax`, `c1_terminal`, `c1_relay_b`, `c1_core`, `c1_breaker_a`, `c1_antenna`), `ActionKey`, `ObjectKey`, optional `HoldDuration`, `MaxDistance` |
| `FZ_Door` | Schiebetür (Part) | `Open` (bool), `Locked` (bool), `PowerSector` (z. B. `B`), `ClosedCFrame`, `OpenCFrame` (CFrame) + `PathfindingModifier` |
| `FZ_SectorLight` | Lampe, die mit Strom an/aus geht | `Sector` (`A`–`E`, `CORE`, `CONTROL`, `HALL`), `OnColor` (Color3) |
| `FZ_KeyLight` / `FZ_DecorLight` | Grafikstufen: Key-Lichter sind immer an, Deko-Lichter skalieren | – |
| `FZ_FuseSpot` | mögliche Sicherungs-Fundorte (pro Sektor mehrere) | `Sector` |
| `FZ_CreaturePatrol` | Patrouillenpunkte der Kreatur (unsichtbare Parts) | `Area` |
| `FZ_Vent` | Lüftungsschacht-Öffnung | `VentGroup` |
| `FZ_CreatureSpawn` | Erscheinungsort der Kreatur | – |
| `FZ_Checkpoint` | Kontrollpunkte | `CheckpointId` (`C1_START`, `C1_CONTROL`, `C1_CORE`) |
| `FZ_MenuCamera` | Kameraposition im Hauptmenü | – |
| `FZ_WorldText` | TextLabel auf SurfaceGui, wird pro Spieler übersetzt | `LocKey`, optional `LocParam_<name>` |
| `FZ_AmbientSource` | Part mit Dauergeräusch | `SoundLoop` (z. B. `generator_loop`) |

Für deinen Lageplan (Damm, See, Kirche, Mine, Fabrikruine) gilt dasselbe. Diese Orte sind als Schauplätze für Kapitel 2–4 vorgesehen.

## Ergänzungen ab 0.4.0 (Kapitel 2–4)

| Tag / Attribut | Wofür |
|---|---|
| `FZ_FloodWater` | Sichtbares Wasser, das ein Kapitel bei eingetretener Flut-Prognose einblendet (blockiert nie die Bewegung) |
| `FZ_Layer` + `Layer` (`now`/`2009`), `BaseTransparency`, `BaseCollide` | Teile, die nur in einer Zeitschicht existieren (Kapitel 4) |
| Tür-Attribute `Canteen`, `Gallery`, `YardGate`, `Hidden`, `ArchiveGate`, `Sealed`, `MineGate`, `LoopDoor`, `PumpDoor`, `BlastDoor` | Türen, die ein Kapitel gezielt sperrt/öffnet |
| `LockedAtStart` (automatisch) | Ausgangszustand einer Tür; wird bei jedem Session-Start wiederhergestellt |
| `FZ_Tags` (Attribut) | Gespeicherte Karten in `ServerStorage.Maps` tragen ihre Tags hier, damit nichts in die laufende Karte „leakt“. MapService setzt sie beim Laden zurück – eigene Karten dort werden beim Start automatisch so umgestellt. |
| `FZ_Builder` (Attribut am Kartenmodell) | Name des Bau-Moduls, das beim Laden Terrain und Licht liefert |

Überlebens-Karten brauchen einen Eintrag in `PROFILES` (`Server/Modes/Survival.luau`): Sektoren, Stationen, Uplink, Ausstieg, Sicherungsziel.

## Optik-Durchgang (`Server/Map/MapDress.luau`, ab 0.5.1)

Läuft nach jedem Kartenbau und fügt nur Optik hinzu: zweifarbige Wände mit Handlauf und Sockelleiste (`WallTrim`), Lichtkegel unter Laternen/Flutlichtern und Mondlicht durch Kirchenfenster (Tag `FZ_LightCone`, folgt der Lampe – Stromausfall schaltet ihn mit aus), Bodennebel und Dampf (Tag `FZ_Mist`, Rate nach Grafikprofil, auf „Niedrig“ aus), Pfützen, flackernde Röhren (Tag `FZ_Flicker`, respektiert „Flackern reduzieren“), Gras-Halme und Bodenfarben beim Terrain sowie `Lighting.LightingStyle = Realistic`. Alles nur mit eingebauten Roblox-Materialien und -Texturen.

