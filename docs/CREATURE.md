# Eigene Kreatur einsetzen

Die KI (`CreatureService`) steuert jedes Modell, das diese Regeln erfüllt. Ohne eigenes Modell wird die eingebaute Platzhalter-Kreatur „Der Lauscher“ gebaut und prozedural animiert.

## So setzt du dein Monster ein (Roblox Studio)

1. In **ServerStorage** einen Ordner **`Creatures`** anlegen.
2. Dein Monster-Modell hineinziehen. Es braucht:
   - einen **`Humanoid`** (mit `Animator` darin),
   - einen Part namens **`HumanoidRootPart`** (wird automatisch `PrimaryPart`),
   - einen Part namens **`Head`** (Blick, Licht-Treffer, Atemgeräusch),
   - eine passende **`HipHeight`** am Humanoid (Abstand Boden → Unterkante HumanoidRootPart),
   - Größe bis ca. 9 Studs Höhe und 4 Studs Breite (Wegfindung: `AgentHeight 9`, `AgentRadius 2`).
3. Animationen (optional, empfohlen): im Animation Editor erstellen, veröffentlichen und die IDs in `src/ReplicatedStorage/Shared/Assets.luau` unter `CreatureAnimations` eintragen (`Idle`, `Walk`, `Run`, `Attack`, `Listen`). Der Server spielt sie je nach KI-Zustand ab.
4. Hat dein Modell Motor6Ds mit denselben Namen wie der Platzhalter (`RootJoint`, `Neck`, `LeftShoulder`, `LeftElbow`, `LeftHip`, `LeftKnee` …), kannst du stattdessen das Attribut `Procedural = true` am Modell setzen und die eingebaute Animation nutzen.

## Verhalten (für Level-Design und Balancing)

| Regel | Wert (`Shared/Config.luau → Creature`) |
|---|---|
| Hört Gehen / Sprinten / Funk / Türen | 7 / 20 / 28 / 16 Studs |
| Sieht | 42 Studs, 65° Sichtkegel, nur mit Sichtlinie |
| Tempo Patrouille / Untersuchen / Jagd | 7 / 11 / 15 (Sprint der Spieler: 16) |
| Angriff | 0,65 s Vorwarnung, 34 Schaden → 3 Treffer bis „am Boden“ |
| Taschenlampe ins Gesicht | 1,8 s geblendet, dann Rückzug, 9 s Abklingzeit |
| Lüftungsschächte | Rasseln am Ausgang 2,5 s vorher + Untertitel |

Zustände: `Dormant`, `Patrol`, `Listen`, `Investigate`, `Search`, `Chase`, `Attack`, `Blinded`, `Retreat`, `Vent` (als Attribut `State` am Modell sichtbar).

## Wartungsmenü (Owner)

Kreatur vor dir erscheinen lassen · KI an/aus · **Als Kreatur spielen** (F / RB = Angriff, Third-Person) · zurück zum Charakter · Teleport zum Kern · Testgeschwindigkeit ×2 · Kreatur & Ereignisse zurücksetzen.
Alles, was andere Spieler treffen kann, funktioniert nur in Studio und in privaten Servern.
