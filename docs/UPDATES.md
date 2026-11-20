# Inhalte erweitern, ohne Spielstände zu zerstören

## Architektur in einem Satz

`Shared/Content.luau` listet **alles Spielbare** (Modi, Kapitel, Überlebenskarten, Karten, Places). Menüs, Teleports, NEU-Markierungen und Speicherdaten lesen nur von dort. `SessionService` startet pro Server genau eine Sitzung und reicht sie an ein Modus-Modul weiter (`Chapters/*`, `Modes/*`).

```
Content (Registry) ──► Play-Menü (Client)          Updates.luau ──► „Neuigkeiten“ (dezenter Punkt)
        │
        ▼
SessionService ──► MapService (Karte laden) ──► Modus-Modul: Init / Begin / Stop / OnPlayerEntered
        │                                         Chapter1 · Survival · (Chapter2 …)
        └──► PlaceService (optional: Teleport in einen eigenen Place, reservierter Server)
```

## Neues Kapitel hinzufügen (Checkliste)

1. Karte bauen: in Studio als Modell unter `ServerStorage/Maps/<Name>` **oder** als Builder-Modul in `Server/Map/`. Die Tags stehen in `MAP_CONTRACT.md`.
2. `Content.Maps` erweitern und beim Kapitel `status = "available"` sowie `since = "<Version>"` setzen.
3. Modul `Server/Chapters/ChapterN.luau` mit `Init`, `Begin`, `Stop`, `OnPlayerEntered` und `StartCheckpoint` anlegen (Vorlage: `Chapter1`). In `SessionService.MODULES.story` eintragen.
4. Texte in allen 5 Sprachen ergänzen und `python3 tools/check_localization.py` laufen lassen.
5. `Shared/Updates.luau` oben einen Eintrag hinzufügen und `Config.Version` erhöhen.
6. Optional einen eigenen Place anlegen und dessen ID in `Content.Places` eintragen. Dieselbe Place-Datei wird in alle Places veröffentlicht, den Rest erledigt das Spiel.

Eine neue Überlebenskarte funktioniert genauso über `Content.SurvivalMaps`. `Modes/Survival.luau` läuft auf jeder Karte, die die getaggten Objekte hat: Sicherungsfundorte, Relais, Kern, Generatoren, Antenne.

## Spielstände: Versionen und Migrationen

- Jeder Spielstand trägt `version`. Die aktuelle Version steht in `Config.Data.SchemaVersion`, derzeit **2**.
- **Neue Felder mit Standardwert** brauchen keine Migration: `reconcile()` ergänzt sie beim Laden automatisch.
- **Umbauten** (z. B. v1 → v2: Kapitel-Fortschritt von Nummern auf IDs) laufen als eigene Funktion in `MIGRATIONS[n]` in `DataService`. Dabei gilt:
  - Eine veröffentlichte Migration wird nie mehr geändert.
  - Eine Migration ergänzt oder formt um. Sie löscht nie Währung, Inventar, Einstellungen oder Fortschritt.
  - IDs (Codes, Shop-Items, Kapitel, Karten) sind dauerhaft. Wird ein Item eingestellt, bleibt es im Inventar.
- **Schutz bei laufenden Updates:** Lädt ein *alter* Server einen Spielstand mit einer *höheren* Version, nutzt er ihn nur für diese Sitzung und speichert ihn nie zurück. Der Spieler sieht einen Hinweis, dass er neu beitreten soll.
- **Session-Lock:** Ein Spielstand gehört immer nur einem Server (siehe `DataService`). So entstehen keine Duplikate beim Serverwechsel.
- **Notfall:** Roblox-DataStores speichern ältere Versionen jedes Schlüssels. Einen Spielstand kann man mit `DataStore:ListVersionsAsync` / `GetVersionAsync` wiederherstellen, ohne Code zu ändern.

## Veröffentlichen eines Updates (Reihenfolge)

1. `python3 tools/check_localization.py && python3 tools/check_luau_blocks.py`
2. In Studio testen: alter Spielstand → neuer Code (Migration), Kapitel und Überleben einmal durchspielen.
3. Veröffentlichen. Danach im Creator Hub die alten Server neu starten („Migrate to latest update“). Durch den Versionsschutz ist das ohne Risiko.
