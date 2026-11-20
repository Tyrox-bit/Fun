# FREQUENCY ZERO – Game Design Document (v0.1)

> Arbeitsdokument. Enthält vollständige Spoiler. Änderungen an Story und Mechaniken werden hier gepflegt, damit Code und Konzept nicht auseinanderlaufen.

---

## 1. Finales Konzept

**Pitch:** Ein Team aus 1–4 Technikern soll die seit Jahren stillgelegte Relaisstation VESPER-4 inspizieren, weil sie wieder sendet. Das Funkgerät in ihrer Hand empfängt Hilferufe von Menschen, die seit 2009 verschwunden sind – und Durchsagen, die beschreiben, was gleich passieren wird.

**Alleinstellungsmerkmal – „Prognosen“:**
*Das Funkgerät sagt euch die Zukunft. Ihr entscheidet, ob sie eintritt.*

Die Station sendet konkrete Vorhersagen („02:31 – Die Schleuse im Westflügel schließt sich. Jemand bleibt zurück.“). Spieler können eine Prognose eintreten lassen (sicher, vorhersehbar) oder sie **brechen** (riskant: die Station „reißt“, Räume verändern sich, neue Wege und Geheimnisse entstehen, die Kreatur wird aufmerksam). Dadurch hat fast jede Szene eine echte Entscheidung – und Horror entsteht aus dem Wissen, was kommen *könnte*.

**Kerngefühl-Kurve pro Kapitel:** Neugier → Verunsicherung → Erwartungsangst → Konfrontation → Erkenntnis → neue Frage.

**Was wir bewusst nicht machen:** Schlüssel-Sammel-Flure, permanente Verfolgung, Schreck-Schubladen, Zufallstode, Codes ohne Weltbezug, Pay-to-Win.

---

## 2. Story-Architektur

### Hintergrund (nie am Stück erzählt, nur in Fundstücken)

- **VESPER-4** – regionale Notruf-Relaisstation in einem bewaldeten Mittelgebirge, gebaut 1979. Ab 2004 betreibt die Station das experimentelle **Echo-Array**, um Notrufe über Ionosphären-Reflexion weiter zu tragen.
- Nachtoperatorin **June Okafor** entdeckt 2008 einen Träger ohne Frequenzversatz – intern „**Frequenz Null**“. Signale darauf kommen an, *bevor* sie gesendet werden: bis zu 41 Minuten.
- Stationsleiterin **Mara Venn** nutzt die Vorabsignale, um Unfälle im Umland zu verhindern. Es funktioniert – fast immer. Die Station protokolliert jede „Korrektur“.
- **Nacht vom 14. November 2009, 02:14:** Das Array empfängt einen Notruf *der Station selbst*, 41 Minuten in der Zukunft. Funktechniker **Tobias Ehle** will antworten, um es zu verhindern. Die Antwort auf Frequenz Null schließt die Schleife: Die Station „faltet“ sich um 02:14. Sechs Menschen verschwinden. Offiziell: Brand, Stilllegung, Akten geschlossen.
- **Der Lauscher** (die Kreatur) ist die Rückkopplung der Schleife: alles, was je auf Frequenz Null beantwortet wurde, zu einer Gestalt verdichtet. Er sucht nach Geräuschen, weil jedes Geräusch eine mögliche Antwort ist.

### Die Stimmen

| Stimme | Wer sie zu sein scheint | Wer sie wirklich ist |
|---|---|---|
| **Unbekannte Stimme** (warm, Amber-Untertitel) | Verschwundene von 2009 | Echos der 2009-Crew, in der Schleife gefangen. Sie wiederholen ihre letzte Nacht – und reagieren zunehmend auf die Spieler. |
| **Das Relais** (kühl, Teal-Untertitel) | Ein Überlebender / Systemstimme, der euch hilft | **Euer eigenes Team aus einem späteren Durchlauf.** |

### Kapitel und Offenbarungen

**Kapitel 1 – Der Empfang** (Pförtnerloge, Empfangshalle, Schaltraum, Überwachung)
Einführung Funkgerät, erste Prognose, erster Kontakt mit dem Lauscher (nur Andeutung), erste Entscheidung (Notstrom verteilen).
*Offenbarung 1:* Die Signale stammen nicht nur aus der Vergangenheit – manche sagen voraus. Beweis: Die Überwachungskamera zeigt die Spieler 20 Sekunden in der Zukunft.
*Cliffhanger:* Das Relais nennt einen Spieler beim Namen: „Diesmal nicht die linke Tür.“ – *diesmal?*

**Kapitel 2 – Die falsche Stimme** (Mannschaftstrakt, Kantine, Antennenhof bei Sturm)
Prognosen werden persönlicher. Die Spieler entdecken, dass gebrochene Prognosen die Station real verändern (Räume, Wege, Begegnungen). Der Lauscher jagt aktiv.
*Offenbarung 2:* Entscheidungen verändern, was geschieht. Die 2009-Crew hat genau das versucht – mit Korrekturprotokollen, die zeigen, dass jede Korrektur eine andere Katastrophe auslöste.
*Wendepunkt:* Zwei Stimmen widersprechen sich zum ersten Mal: Die Unbekannte Stimme fleht „Antwortet uns!“, das Relais sagt „Nicht antworten. Noch nicht.“ Welche Stimme ist die „falsche“?

**Kapitel 3 – Das Protokoll** (Archiv, Tonbandraum, Echo-Array-Kontrollraum)
Die Spieler rekonstruieren die Nacht von 2009 aus Tonbändern (Rätsel über Hören und Ordnen, keine Codes).
*Offenbarung 3 – der große Twist:* Im versiegelten Operatorraum liegt ein Funkgerät – **mit dem Design, das ein Spieler gerade ausgerüstet hat** (kosmetisches Item des Spielers). Daneben ein Rekorder mit den Relais-Aufnahmen, signiert mit den **Roblox-Anzeigenamen des Teams** und einem Durchlaufzähler: `DURCHLAUF 0007`. Das Relais ist das eigene Team. Es hat am Ende eines früheren Durchlaufs auf Frequenz Null **geantwortet** – und ist dadurch selbst zur Stimme geworden, die das nächste Team (sich selbst) hierher lotst. Der Arbeitsauftrag per Fax („gesendet: morgen, 02:14“) kam vom Relais.
*Warum es emotional trifft:* Das Relais klingt mit jedem Kapitel müder und verrauschter – jeder Durchlauf degradiert das Signal. Es hat einmal gelogen („Die Crew von 2009 kann gerettet werden, wenn ihr antwortet“), weil es selbst nicht mehr weiß, ob es enden will.

**Kapitel 4 – Frequenz Null** (Array-Kern unter der Station, die Station „falsch herum“)
Die Station bricht in Zeitschichten auf (2009 / heute / Schleife). Finale Kombination aller Mechaniken: Prognosen brechen, um einen Weg zu öffnen; Lauscher ausweichen; gemeinsam den Kern erreichen.

### Die Enden

| Ende | Bedingung | Ausgang |
|---|---|---|
| **Antworten** | Am Kern senden | Das Team entkommt – scheinbar. Epilog: Ein Faxgerät druckt einen neuen Auftrag mit morgigem Datum. Die Relais-Stimme ist nun hörbar die eigene. Nächster Durchlauf (Neues Spiel+) beginnt mit „Ihr seid zurück.“ |
| **Stille** | Nicht senden, Array auf Null fahren | Das Relais verabschiedet sich („Danke. Wir hören uns nicht.“). Die 2009-Crew bekommt endlich eine Antwort von *außen* – die Zeit läuft weiter. Morgendämmerung, die Funkgeräte verstummen für immer. Das Fax druckt eine leere Seite. |
| **Gegenfrequenz** (geheim) | Alle 6 Geisterprotokolle gefunden + jede Prognoseart mindestens einmal gebrochen | Das Team sendet nicht die eigene Stimme, sondern Junes ersten Ruf von 2008 zurück – an June selbst, mit einer Warnung. Die Schleife wird an ihrem Ursprung verhindert. Die Spieler betreten eine *aktive* Station bei Tageslicht. June begrüßt sie – und erinnert sich an sie. |

### Hinweise für das zweite Durchspielen (der Twist muss fair sein)

1. Das Fax ist auf **morgen, 02:14** datiert (erste Minute des Spiels).
2. „Nicht antworten. **Noch** nicht.“ – das Relais weiß, dass ihr am Ende antworten könnt.
3. Das Relais spricht von „**wir**“, nie von „ich“.
4. Das Relais kennt die Anzeigenamen der Spieler, ohne dass sie sich vorgestellt haben.
5. Im Funkrauschen des Relais liegen gelegentlich **die Schrittgeräusche der Spieler** (gleicher Untergrund-Sound).
6. Fragt man das Relais per Dialogoption „Wer bist du?“, entsteht eine Pause von genau der Länge, die eine Antwort auf Frequenz Null braucht (41 Frames Stille – im Tonband-Rätsel in Kap. 3 erklärt).
7. Logbuch der Pförtnerloge: letzter Eintrag 02:14, Handschrift wechselt zu Druckbuchstaben – „VESPER-0214“ (zugleich ein Code).
8. Durchlaufzähler an Terminals sind schon in Kapitel 1 sichtbar, aber unkommentiert (`0007`).
9. „Diesmal nicht die linke Tür.“ – in Kapitel 1 führt die linke Tür tatsächlich zum Lauscher.

---

## 3. Die fünf Kernmechaniken

### 1. Das Funkgerät (Empfangen statt Menüs)
- Gedrückt halten = Funkgerät anheben (Viewmodel). Die Richtung, in die man schaut, ist die „Antenne“: Rauschen wird klarer, je näher man der Quelle zugewandt ist, eine Nadel schlägt aus. Kein Frequenzmenü, keine Zahlen.
- Taps auf „Weiter“ springen zwischen maximal 3 aktiven Kanälen (Story, Prognose, Geheimnis).
- **Warum es Spaß macht:** Physisches Suchen im Raum, sofort verständlich, erzeugt Spannung durch Hören. Gleichzeitig Risiko: Lautes Rauschen lockt den Lauscher (siehe 3).

### 2. Prognosen brechen
- Jede Prognose hat Uhrzeit, Ort und Ereignis. Wanduhren in der Station laufen synchron (lesbar auf allen Grafikstufen).
- Eintreten lassen = sicherer Weg. Brechen = aktive Handlung (Tür blockieren, Strom umleiten, Person warnen) → „Riss“: Raum verändert sich, alternative Begegnung, Lore-Belohnung, Signalmarken.
- **Warum:** Echte Spielerautonomie, Wiederspielwert, Diskussionen im Team („Lassen wir es passieren?“).

### 3. Der Lauscher (Kreatur)
- **Silhouette:** über 2,5 m, extrem schmal, Kopf ist ein alter Trichterlautsprecher mit Stoffbespannung, zu lange Arme, bewegt sich in **Signalaussetzern** (springt wenige Frames wie ein abreißender Stream). Jeder Sprung wird von einem kurzen statischen Knacken angekündigt – Warnsignal und Markenzeichen.
- **Audio-Identität:** wiederholt verzerrt, zeitversetzt, was er gehört hat – inklusive der Schritte der Spieler.
- **Regeln (fair und lernbar):** Hört Gehen in 6 m, Sprinten in 18 m, aktive Funkübertragung in 25 m. Licht ist ihm egal (Taschenlampe ist sicher). Stillstand macht unhörbar.
- **Zustände:** Ruhend → Patrouille → Lauschen (bleibt stehen, Kopf neigt sich, Knacken) → Untersuchen (läuft zum letzten Geräusch) → Suchen (Raster um den Punkt) → Verfolgen (nur bei direktem Kontakt < 8 m, angekündigt) → Rückzug (verliert Spur, kehrt in sein Revier zurück).
- **Gefangen werden:** kein Sofort-Tod. Der Spieler wird zum **Echo** (Bild rauscht, er hört das Team nur noch übers Funkgerät). Mitspieler können ihn innerhalb von 25 s an seiner Position „zurückstimmen“ (Interaktion). Solo/zu spät: Rückkehr zum letzten Checkpoint, nichts geht verloren.
- Server-autoritativ (PathfindingService, Zustandsmaschine auf dem Server), Clients rendern nur Animation/Audio.

### 4. Getrennte Wahrnehmung (sparsam!)
- Höchstens 1 Moment pro Kapitelabschnitt, insgesamt 5 im Spiel. Beispiele: Nur ein Spieler sieht die Gestalt im Überwachungsmonitor; zwei Spieler hören auf demselben Kanal verschiedene Sätze; ein Spieler hört seinen eigenen Namen.
- Technisch: Server sendet gezielt an einzelne Clients (`StoryService.Say(player, …)`), Geometrie/Effekte rein lokal.
- Solo: Der Moment wird zeitversetzt erzählt (das Relais wiederholt später etwas anderes, als man gehört hat).

### 5. Reaktive Station und Umgebungsrätsel
- **Notstrom verteilen:** Generator hat Kapazität für 2 von 3 Bereichen (Aufzug / Schleuse / Überwachung). Jede Wahl öffnet einen anderen Weg – und eine andere Prognose.
- **Zeitversetzte Überwachung:** Monitore zeigen 20 s in die Zukunft – man sieht, wo der Lauscher gleich sein wird.
- **Tonband-Rekonstruktion (Kap. 3):** Bandfragmente anhören und in die richtige Reihenfolge bringen – Hinweise sind Umgebungsgeräusche (Regen beginnt, Tür fällt zu), keine Zahlen. Controller/Touch: Fragmente per Auswahl tauschen, kein Drag & Drop.
- **Koop-Skalierung:** Aufgaben mit mehreren Schaltern haben Timer, die solo großzügig sind; im Team gibt es parallele Teilaufgaben statt „alle müssen gleichzeitig drücken“.

---

## 4. Die ersten zehn Minuten (Spielersicht, Solo oder Koop)

| Zeit | Was passiert | Spielerhandlung / Gefühl |
|---|---|---|
| 0:00 | Logo auf Schwarz, dann (nur beim ersten Start) Sprachauswahl mit vorausgewählter Sprache. Ein Tastendruck. | Kein Warten. |
| 0:05 | Hauptmenü über einer Live-Szene: Nachtregen, das Tor von VESPER-4, eine Natriumlampe flackert. „Jemand sendet noch.“ | „Spielen“ – sofort im Spiel. |
| 0:10 | Spawn direkt vor dem Tor. Funkrauschen. *„…VESPER-4 an alle, die das empfangen. Bitte. Jemand ist im Gebäude.“* | Neugier: Die Station ist doch stillgelegt? |
| 0:20 | *„Sie sind gerade angekommen. Sie stehen am Tor.“* | Gänsehaut: Die Stimme beschreibt **dich**. |
| 0:30 | In der Pförtnerloge beginnt ein Faxgerät zu drucken (Untertitel + rote LED als Lichtführung). Ziel: „Sieh in der Pförtnerloge nach.“ | Erste Interaktion (unsichtbares Tutorial: Prompt zeigt E / X / Tippen). |
| 0:45 | Fax: Arbeitsauftrag 0214 – „Eingehende Rufe nicht beantworten. Gesendet: **morgen**, 02:14.“ | Erster Widerspruch zur Erklärung „alte Technik“. |
| 0:55 | Neue, kühle Stimme: *„Nicht antworten. Noch nicht.“* Ziel: „Finde heraus, wer da sendet.“ | Zwei Stimmen – wem glaube ich? |
| 1:30 | Empfangshalle im Notlicht. Funkgerät-Einführung: Ein Kanal knistert, je nachdem, wohin man blickt. Am Schwarzen Brett: Wartungsnotiz mit `SIGNAL-017`. | Lernen durch Tun, optionales Geheimnis. |
| 2:30 | Überwachungsraum: Ein Monitor zeigt den Korridor – **das eigene Team läuft dort gerade entlang**, obwohl alle hier stehen. Hinter der letzten Figur steht etwas Großes. Im Koop sieht diese Gestalt nur ein Spieler. | „Was zur Hölle war das?“ – kein Angriff, nur Erkenntnis. |
| 3:00 | 20 s später läuft das Team tatsächlich durch diesen Korridor. Nichts ist da. Nur ein statisches Knacken weit hinten. | Erwartungsangst. |
| 3:30 | Schaltraum: Notstrom reicht für 2 von 3: Aufzug, Sicherheitsschleuse, Überwachung. Die erste Prognose: *„02:21 – Wenn der Aufzug fährt, geht im Archiv das Licht aus. Dann hört er euch.“* | Erste echte Entscheidung (gemeinsam oder solo). |
| 4:30 | Je nach Wahl: schneller Weg mit Risiko oder Umweg mit Geheimnis. | Konsequenzen sofort spürbar. |
| 5:00–7:00 | (Bei Aufzugwahl) Archiv geht dunkel. Der Lauscher erscheint zum ersten Mal **sichtbar**: am Ende des Gangs, Kopf geneigt, lauschend. Geht man langsam, passiert nichts. Sprintet man, untersucht er. | Regeln lernen ohne Tutorialtext. |
| 7:00–9:00 | Kurze, entkommbare Begegnung im Treppenhaus (Checkpoint davor). Taschenlampe bleibt an – „Licht ist ihm egal“ wird erlebbar. | Höhepunkt Abschnitt 1. |
| 9:30 | Ruhiger Moment im Pausenraum: Kaffee noch warm, ein Kalender auf November 2009. Das Relais: *„[Spielername], diesmal nicht die linke Tür.“* | Neue Frage: *diesmal?* → Weiterspielen. |

Im aktuellen Build (v0.1) spielbar: 0:00–0:55 im Greybox-Testgelände. Der Rest ist der Bauplan für Phase 2/3.

---

## 5. World Design – erster spielbarer Bereich (Kapitel 1, Abschnitt A)

```
                         N
   [Archiv]────[Treppenhaus]──►(Ebene -1, Abschnitt B)
      │  ▲ dunkel bei Aufzugwahl
      │
 [Korridor A]────────[Überwachung]
      │      linke Tür  │ Monitore (20 s Zukunft)
      │                 │
 [Empfangshalle]────[Schaltraum]  Notstrom 2 von 3
   │ Schwarzes Brett     │
   │ (SIGNAL-017)        └─[Aufzug]──►(Ebene -1, Abkürzung)
   │
 [Windfang]
   │
 [Pförtnerloge]  Fax (Auftrag 0214), Logbuch (VESPER-0214)
   │
 [Tor / Zufahrt]  ← Spawn, Natriumlampe, Regen
```

| Raum | Zweck | Interaktion | Storyereignis |
|---|---|---|---|
| Tor / Zufahrt | Starker erster Eindruck, Orientierung (Lampe führt Blick zur Loge) | – | Ankunftsfunkspruch (pro Spieler) |
| Pförtnerloge | Erste Interaktion, Lichtführung über rote Fax-LED | Fax lesen, Logbuch (Code) | Fax „morgen, 02:14“; Relais-Erstkontakt |
| Empfangshalle | Funkgerät lernen, großer Raum mit Notlicht | Kanal finden, Schwarzes Brett | Erste Unbekannte-Stimme-Peilung |
| Überwachung | Story-Schreckmoment, getrennte Wahrnehmung | Monitore umschalten | Team in der Zukunft gesehen |
| Korridor A | Erwartungsangst durch Ankündigung | – | Knacken, nichts erscheint |
| Schaltraum | Erstes Rätsel + Entscheidung | Sicherungen verteilen (3 große Hebel) | Erste Prognose |
| Archiv / Treppenhaus | Erste Kreaturbegegnung (fair, entkommbar) | Leise gehen, Taschenlampe | Lauscher-Einführung |

Laufwege: keiner länger als ~25 s ohne Ereignis, Interaktion oder Sichtachse auf das nächste Ziel.

---

## 6. Art Direction

- **Ort:** Europäischer Behörden-Brutalismus der späten 70er, Technik aus den 90ern/2000ern: Sichtbeton, lackierter Stahl (Graugrün), Linoleum, Bakelit, Glasbausteine, Kabeltrassen. Jeder Raum hat eine Funktion, die man ihm ansieht.
- **Materialien:** PBR-SurfaceAppearance für Hero-Objekte (Funkgerät, Fax, Konsolen, Kreatur), MaterialVariants (Beton-, Linoleum-, Lackvarianten) für Architektur – keine Free Models.
- **Farbwelt:** Entsättigtes Teal in den Schatten, warmes Natrium-Orange für praktische Lichtquellen, **ein** Akzent: Signalrot für Interaktion/Gefahr/Live-Signal. Kühles Weiß ausschließlich für Zukunftsmomente (Monitore, Prognosen). UI übernimmt exakt diese Palette (`UI/Theme.luau`).
- **Licht:** Future-Lighting, wenige starke Lichtquellen mit Schatten statt vieler schwacher. Licht führt (Fax-LED, Notlicht-Pfeile). Gameplay-relevante Lichter tragen das Tag `FZ_KeyLight` und sind auf jeder Grafikstufe aktiv; Deko-Lichter `FZ_DecorLight` skalieren.
- **Dunkelheit:** Ambient nie auf Schwarz; Silhouetten lesbar. Helligkeitsregler 0–10 in den Einstellungen.
- **Atmosphäre:** Atmosphere-Dunst (identisch auf allen Profilen – Fairness), Regen draußen, Staub im Taschenlampenkegel (Partikel skalieren mit Profil).
- **Animation:** Funkgerät-Viewmodel mit Anheben/Senken/Nadel; Kamera ohne übertriebenes Wackeln (FOV-Änderung beim Sprint, abschaltbar). Lauscher: Stotterbewegung durch absichtliche Pose-Sprünge, nicht durch Lag.
- **Audio:** Neue Roblox-Audio-API (AudioPlayer/AudioEmitter/AudioListener mit AudioReverb/AudioEqualizer) für räumliches Funkrauschen und Hall; Mix-Busse: Stimmen/Funk (Vorrang, duckt Ambience um ca. 6 dB) > Kreatur > SFX > Ambience > Musik > UI. Stille als Werkzeug: vor jedem Höhepunkt 3–6 s ohne Ambience-Layer. Jedes sicherheitsrelevante Geräusch hat einen Untertitel (`critical = true` wird auch bei ausgeschalteten Untertiteln gezeigt).

---

## 7. Systeme, Monetarisierung, Codes, Qualität

### Systemstatus

| System | Datei | Status v0.1 |
|---|---|---|
| LocalizationManager (5 Sprachen) | `Shared/Localization` | fertig |
| Netzwerk-Remotes, Session-State | `Shared/Net`, `Shared/SessionState` | fertig |
| SaveData mit Session-Lock | `Server/Services/DataService` | fertig |
| Settings (Sprache, Untertitel, Schreck, Kamera, Grafik, Helligkeit) | `SettingsService`, `SettingsController`, `GraphicsController` | fertig |
| CrossPlatformInput | `Controllers/InputController` | fertig (Studio-Test ausstehend) |
| InteractionSystem | `InteractionService`, `WorldTextController` | fertig |
| GameFlow / Checkpoints | `GameFlowService`, `Chapters/Chapter1` | Grundgerüst |
| UI (Router, Menüs, HUD) | `Client/UI` | fertig |
| CodeRedemption | `CodeService`, `ServerStorage/Secrets/Codes` | fertig |
| OwnerAdmin (Autorisierung, Log) | `AdminService` | Grundgerüst; Welt-Tools folgen mit Kreatur |
| Funkgerät, AudioManager, Lauscher-KI, HorrorDirector, Shop | – | nächste Phasen |

### Monetarisierung (Planung, Umsetzung erst nach dem Vertical Slice)
- **Signalmarken** (verdient: Kapitel, Geheimnisse, gebrochene Prognosen, Codes) → Funkgeräte-Designs, Taschenlampen-Gehäuse, Lobby-Kosmetik, Abzeichen.
- **Gamepasses** für dauerhafte Kosmetik (z. B. Unterstützerpaket mit exklusivem Funkgerät-Gehäuse). **Developer Products** nur für einzelne kosmetische Bundles. Preise erst nach Test und Prüfung der aktuellen Roblox-Richtlinien.
- Shop nur aus dem Menü erreichbar, nie während Verfolgung/Story-Szene, keine Kaufaufforderung nach dem Scheitern. Hauptspiel vollständig ohne Robux.
- Kaufabwicklung ausschließlich über `MarketplaceService.ProcessReceipt` (serverseitig, idempotent über Receipt-ID im Save).

### Codes in der Welt
| Code | Fundort | Belohnung |
|---|---|---|
| `SIGNAL-017` | Wartungsnotiz, Schwarzes Brett | 25 Signalmarken |
| `VESPER-0214` | Logbuch, Pförtnerloge (letzte Zeile) | 40 Signalmarken |

Codes liegen nur in `ServerStorage` (nie beim Client). Hinweis: Weil dieses Repository Codes enthält, kann sie jeder mit Repo-Zugriff lesen – für ein öffentliches Repo später auf eine nicht eingecheckte Quelle umstellen.

### Messbare Qualitätsziele (erste Tests)
- Erste Interaktion (Fax) im Median < 45 s nach „Spielen“.
- ≥ 90 % der Testspieler finden das erste Ziel ohne Hilfe.
- Kapitel 1 abgeschlossen von ≥ 55 % der Starter (Telemetrie über AnalyticsService-Funnel, später).
- Performance: ≥ 30 FPS (p10) auf schwachem unterstütztem Handy im Profil „Niedrig“, ≥ 60 FPS auf Mittelklasse-PC im Profil „Hoch“ – gemessen mit der Leistungsanzeige (Wartungsmenü), nicht geschätzt.
- Jede Aktion mit jedem Gerätetyp erreichbar (Testmatrix in README).
- Kein Text überläuft in einer der 5 Sprachen bei 844×390 (Handy quer) und 1920×1080.

### Altersfreigabe
Psychologischer Horror ohne Blut/Gore. Der Fragebogen zur Erlebnis-Reife (Maturity & Compliance) muss ehrlich ausgefüllt werden; Schreckmomente und eine bedrohliche Kreatur führen voraussichtlich zu einer Einstufung über „Mild“. Die Einstellung „Schreckintensität: Reduziert“ ändert daran nichts, verbessert aber die Zugänglichkeit.
