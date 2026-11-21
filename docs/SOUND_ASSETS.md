# Sound-Asset-Liste

Alle Sounds sind **selbst synthetisiert** (`tools/generate_sounds.py`, keine fremden Samples) und liegen als `.ogg` in `assets/audio/`. Hochladen: Creator Hub → Development Items → Audio. Danach trägst du die ID in `src/ReplicatedStorage/Shared/Assets.luau` ein. **Asset-IDs werden nie erfunden**, ein leerer Eintrag bedeutet „noch nicht hochgeladen“. Das Spiel läuft dann ohne diesen Sound.

**Qualität:**
- 44,1 kHz, mono, Ogg Vorbis q5
- Spitzenpegel ≤ −9 dB (Warnsignale) bzw. ≤ −12 dB (Kreatur, Effekte) bzw. ≈ −20 dB (Ambience und Musik)
- Keine Lautstärkesprünge

**Räumlich:** 3D-Wiedergabe mit Abstandsdämpfung (InverseTapered), Raumhall je Bereich (`SoundService.AmbientReverb`). Geräusche hinter Wänden werden gedämpft (Tiefpass, wenn die Sichtlinie verdeckt ist).

**Varianten:** Namen mit `_1`, `_2` … werden zufällig rotiert, und dieselbe Variante kommt nie zweimal hintereinander.

**Fairness:**
- `creature_alert` ist das einzige Jagd-Warnsignal und wird **nie** als Täuschung benutzt.
- Täuschungsgeräusche laufen leiser und nie während einer echten Verfolgung.

| Name | Beschreibung | Dauer | Typ | Verwendung |
|---|---|---|---|---|
| `radio_static_loop` | Funkrauschen mit Knistern, Schleife | 3.8 s | Schleife | Hintergrund beim Funkempfang, wird mit Entfernung lauter |
| `radio_squelch_on` | Klick + Rauschstoß | 0.2 s | einmalig | Funk: Senden beginnt / Empfang beginnt |
| `radio_squelch_off` | Roger-Piep + Rauschende | 0.3 s | einmalig | Funk: Senden endet |
| `radio_channel_beep` | Doppelpiep | 0.1 s | einmalig | Kontrollrunde, Bestätigungen |
| `hum_electric_loop` | 50-Hz-Netzbrummen, Schleife | 3.8 s | Schleife | Ambience innen |
| `generator_loop` | Generator-Wummern, Schleife | 3.8 s | Schleife | 3D-Quelle Sektor E |
| `ambience_wind_loop` | Wind mit Böen, Schleife | 9.2 s | Schleife | Ambience außen |
| `creature_click` | Klick-Serie (Stotter) | 0.5 s | einmalig | Kreatur: zufällige Klicks |
| `creature_static_burst` | Statik mit Aussetzern | 0.5 s | einmalig | Kreatur: Signalaussetzer, Treffer, geblendet |
| `creature_breath` | Atem kurz | 2.4 s | einmalig | alte Atemschleife (Fallback) |
| `creature_alert` | Fallender Ton + Statik | 1.1 s | einmalig | WARNSIGNAL: Kreatur beginnt Jagd (nie als Täuschung verwendet) |
| `heartbeat` | Herzschlag | 0.9 s | einmalig | reserviert für Nahbedrohung |
| `footstep_concrete_1` | Schritt Beton | 0.2 s | einmalig | Schritte Spieler |
| `footstep_concrete_2` | Schritt Beton | 0.2 s | einmalig | Schritte Spieler |
| `footstep_concrete_3` | Schritt Beton | 0.2 s | einmalig | Schritte Spieler |
| `footstep_metal_1` | Schritt Metall | 0.2 s | einmalig | Schritte Spieler |
| `footstep_metal_2` | Schritt Metall | 0.2 s | einmalig | Schritte Spieler |
| `footstep_grass_1` | Schritt Gras/Kies | 0.2 s | einmalig | Schritte außen |
| `footstep_grass_2` | Schritt Gras/Kies | 0.2 s | einmalig | Schritte außen |
| `door_open` | Schiebetür + Anschlag | 1.2 s | einmalig | Türen |
| `door_locked` | Summer | 0.3 s | einmalig | verschlossene Tür |
| `fuse_pickup` | Metallklirren | 0.5 s | einmalig | Aufheben |
| `relay_activate` | Hochlaufen + Klacken | 2.0 s | einmalig | Relais, Generator, Hebel |
| `power_down` | Abfallender Brummton | 2.2 s | einmalig | Stromausfall |
| `vent_rattle` | Metallrasseln | 1.6 s | einmalig | Lüftungsschacht (Ankündigung) |
| `ui_focus` | leiser Tick | 0.0 s | einmalig | Menüfokus |
| `ui_select` | Doppelklick | 0.1 s | einmalig | Menüauswahl |
| `stinger_low` | Dissonante Schwelle | 3.5 s | einmalig | seltener Schreck (nur Intensität 'intensiv') |
| `music_menu` | Dunkle Fläche, 24 s Schleife | 22.0 s | Schleife | Hauptmenü |
| `tension_low` | Tiefes Schweben, Schleife | 14.5 s | Schleife | Spannung: Kreatur in der Nähe |
| `tension_high` | Pulsierende Dissonanz, Schleife | 7.5 s | Schleife | Spannung: Verfolgung |
| `creature_breath_deep_1` | Tiefes, unregelmäßiges Atmen mit Rasseln | 3.3 s | einmalig | Kreatur: Atem (Varianten rotieren), auch als Täuschung hinter Wänden |
| `creature_breath_deep_2` | Tiefes, unregelmäßiges Atmen mit Rasseln | 2.6 s | einmalig | Kreatur: Atem (Varianten rotieren), auch als Täuschung hinter Wänden |
| `creature_breath_deep_3` | Tiefes, unregelmäßiges Atmen mit Rasseln | 2.7 s | einmalig | Kreatur: Atem (Varianten rotieren), auch als Täuschung hinter Wänden |
| `creature_growl_1` | Raues, unnatürliches Knurren | 2.0 s | einmalig | Kreatur: Lauschen/Untersuchen, Täuschung |
| `creature_growl_2` | Raues, unnatürliches Knurren | 1.5 s | einmalig | Kreatur: Lauschen/Untersuchen, Täuschung |
| `creature_growl_3` | Raues, unnatürliches Knurren | 1.8 s | einmalig | Kreatur: Lauschen/Untersuchen, Täuschung |
| `creature_crack_1` | Knackende Gelenke | 0.6 s | einmalig | Kreatur: Bewegung, Täuschung |
| `creature_crack_2` | Knackende Gelenke | 0.6 s | einmalig | Kreatur: Bewegung, Täuschung |
| `creature_crack_3` | Knackende Gelenke | 0.6 s | einmalig | Kreatur: Bewegung, Täuschung |
| `creature_crack_4` | Knackende Gelenke | 0.6 s | einmalig | Kreatur: Bewegung, Täuschung |
| `creature_drag_1` | Schleifender Schritt mit Aufprall | 1.2 s | einmalig | Kreatur: Schritte (synchron zum Gang) |
| `creature_drag_2` | Schleifender Schritt mit Aufprall | 1.0 s | einmalig | Kreatur: Schritte (synchron zum Gang) |
| `creature_drag_3` | Schleifender Schritt mit Aufprall | 1.0 s | einmalig | Kreatur: Schritte (synchron zum Gang) |
| `creature_rhythm` | Unregelmäßiges Klopfen | 3.2 s | einmalig | Täuschung/Kreatur sucht |
| `voices_muffled_1` | Gedämpfte Stimmen hinter einer Wand | 3.5 s | Schleife | Täuschung: Stimmen im Nebenraum |
| `voices_muffled_2` | Gedämpfte Stimmen hinter einer Wand | 3.5 s | Schleife | Täuschung: Stimmen im Nebenraum |
| `speaker_voice_1` | Verzerrte Lautsprecherstimme mit Aussetzern | 3.0 s | einmalig | Lautsprecher überträgt eine fremde Stimme |
| `speaker_voice_2` | Verzerrte Lautsprecherstimme mit Aussetzern | 3.0 s | einmalig | Lautsprecher überträgt eine fremde Stimme |
| `approach_corridor` | Schritte nähern sich, werden schneller | 6.5 s | einmalig | Täuschung: etwas kommt den Gang entlang |
| `glass_tap` | Klopfen an Glas | 0.5 s | einmalig | Gestalt hinter der Scheibe |
| `light_click` | Relaisklick | 0.2 s | einmalig | Licht im Nebenraum geht an |
| `thunder_1`, `thunder_2` | Donner (Krachen + Grollen) | 6 s | einmalig | Kapitel 2, Sturm auf der Staumauer |
| `rain_loop` | Regen | 5.5 s | Loop | Kapitel 2, draußen |
| `bell_toll` | Kapellenglocke | 7 s | einmalig | Kapitel 3 |
| `tape_play` | Tonbandmaschine startet | 3.5 s | einmalig | Kapitel 3, Tonband-Rätsel |
| `water_rush_loop` | Rauschendes Wasser | 4.5 s | Loop | Kapitel 2 Galerie, Kapitel 4 Pumpe |
| `metal_crash` | Förderkorb schlägt auf | 3 s | einmalig | Kapitel 4 |
| `array_pulse` | Das Echo-Array verschiebt die Zeitschicht | 4 s | einmalig | Kapitel 4 |

## Später echte Aufnahmen (optional)
Wenn ihr Sprecher oder Foley aufnehmt, gilt: dieselben Namen, gleiche Länge (±30 %), mono, 44,1 kHz/24 Bit Quelle, als Ogg q5 hochladen. Die IDs ersetzt ihr in `Assets.luau`, und der Code bleibt unverändert.
