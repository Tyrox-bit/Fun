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
