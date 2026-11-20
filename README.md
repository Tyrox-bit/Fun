# Casper – Black Friday Landing Page 🔥

Aktionsseite mit Shop für das **Casper Damast-Duo** (Kochmesser + Schälmesser).
Optimiert für Traffic von Instagram und TikTok: mobil zuerst, schnell, ohne Framework.

**Bezahlen:** Stripe Checkout mit PayPal, Klarna, Karte, Apple Pay und Google Pay in **einer** Integration.
**Hosting:** Vercel (kostenloser Tarif reicht).

---

## Was drin ist

| Feature | Details |
|---|---|
| Countdown | Topbar + Angebotsbereich + Schluss-CTA. Nach Aktionsende automatisch Normalpreis (Seite **und** Server). |
| Echter Lagerbestand | Wird live aus Stripe berechnet (verkauft + gerade im Checkout reserviert). Kein Überverkauf, keine Datenbank. |
| Bundles | 1 / 2 / 3 Sets mit Preis pro Set, Ersparnis, Versand-Nudge („2. Set kostet nur 80 €“). |
| Sticky-Kaufleiste | Erscheint beim Scrollen, direkt zur Kasse. |
| Echte Social Proof | „Letzte Bestellung vor X Min.“ – nur aus echten Stripe-Daten. Bewertungen erscheinen erst, wenn du echte einträgst. |
| Rabattcodes | Für Creator/Influencer im Stripe-Dashboard anlegen – Feld erscheint im Checkout automatisch. |
| Geschenknachricht | Optionales Feld im Checkout, landet in deiner Bestell-Mail. |
| Lieferdatum | „Lieferung voraussichtlich Di., 24.11. – Do., 26.11.“ (Werktage, live berechnet). |
| Kanal-Tracking | UTM-Parameter & Instagram/TikTok-In-App-Browser werden erkannt und **in jeder Stripe-Bestellung gespeichert**. |
| Pixel-ready | Meta- & TikTok-Pixel: nur ID eintragen → Cookie-Banner + Events (ViewContent, AddToCart, InitiateCheckout, Purchase) laufen. |
| Rechtliches | Impressum, AGB, Widerrufsbelehrung, Datenschutz, Versand & Zahlung, **Widerrufsbutton** (Pflicht seit 19.06.2026). |
| E-Mails | Bestellbestätigung an Kunden, Bestell-Info an dich, Widerrufsbestätigung (über Resend). |
| Link-Vorschau | Eigenes Vorschaubild für Insta-DMs, WhatsApp & Co. |

---

## Livegang in 7 Schritten

### 1. Daten eintragen – `shop.config.json`
Alles Wichtige steht in **einer** Datei:
- `legal` → Name, Adresse, Telefon, USt-ID (füllt automatisch Impressum, AGB usw.)
- `bundles` → Preise in **Cent** (9900 = 99 €)
- `campaign.start` / `campaign.end` → Aktionszeitraum
- `stock.totalSets` → echter Bestand
- `shipping` → Versandkosten, Gratis-Versand ab X Sets, Lieferzeit
- `product.specs` → **bitte alle technischen Angaben prüfen** (67 Lagen, VG-10, HRC …)

### 2. Stripe einrichten
1. Konto auf [stripe.com](https://stripe.com) anlegen und verifizieren.
2. **Einstellungen → Zahlungsmethoden:** PayPal, Klarna, Apple Pay, Google Pay aktivieren. PayPal verknüpfst du dort mit deinem PayPal-Geschäftskonto.
3. **Einstellungen → E-Mails:** „Erfolgreiche Zahlungen“ aktivieren (Stripe-Beleg zusätzlich).
4. **Entwickler → API-Schlüssel:** Secret Key kopieren (zuerst `sk_test_…`).

### 3. Auf Vercel veröffentlichen
1. [vercel.com](https://vercel.com) → mit GitHub anmelden → dieses Repository importieren → *Deploy*. Keine Build-Einstellungen nötig.
2. **Settings → Environment Variables:** Werte aus `.env.example` eintragen.
3. **Settings → Domains:** deine Domain verbinden.
4. Unter **Settings → Legal** den Auftragsverarbeitungsvertrag (DPA) abschließen.

### 4. Webhook für Bestellbestätigungen
Stripe → **Entwickler → Webhooks → Endpunkt hinzufügen**
- URL: `https://DEINE-DOMAIN/api/stripe-webhook`
- Events: `checkout.session.completed`, `checkout.session.async_payment_succeeded`
- Signing Secret → als `STRIPE_WEBHOOK_SECRET` in Vercel eintragen

### 5. E-Mails (Resend)
[resend.com](https://resend.com) → Domain verifizieren → API-Key als `RESEND_API_KEY`, Absender als `MAIL_FROM`, deine Adresse als `SHOP_EMAIL`.
Ohne Resend funktioniert der Shop trotzdem, aber **Bestellbestätigung und Widerrufsbutton brauchen einen Mailversand** – also vor Livegang einrichten.

### 6. Testkauf
Mit `sk_test_…` die Seite öffnen und mit der Testkarte `4242 4242 4242 4242` (beliebiges Datum/CVC) bestellen. Prüfen: Danke-Seite, E-Mails, Bestand sinkt.
Danach `sk_live_…` + Live-Webhook eintragen → **einmal echt kaufen und erstatten**.

### 7. Rechtstexte final machen ⚠️
Die Texte sind **Entwürfe von Claude, keine Rechtsberatung.** Für einen Shop mit echten Kunden:
- **Widerrufsbelehrung + Muster-Widerrufsformular** aus einem Rechtstext-Generator (IT-Recht Kanzlei, Händlerbund, Trusted Shops o. ä.) übernehmen. Die müssen dem gesetzlichen Muster entsprechen.
- AGB und Datenschutz dort prüfen bzw. ersetzen lassen. Die Dienste kosten ca. 10–25 €/Monat und aktualisieren die Texte bei Gesetzesänderungen automatisch.
- Gelb markierte Stellen auf den Seiten = noch offen.

---

## Wichtige rechtliche Hinweise zur Aktion

- **Streichpreis 199 €:** Laut § 11 PAngV muss der durchgestrichene Preis der **niedrigste Preis der letzten 30 Tage vor der Aktion** sein. Wurde das Set nie zu 199 € angeboten (neue Marke), ist „−50 %“ angreifbar. Dann lieber ohne Streichpreis werben (`compareAtPrice` = `salePrice` setzen) oder mit Anwalt klären.
- **Keine Fake-Knappheit:** Countdown und Bestand sind echt. Bitte Aktionsende nicht einfach verlängern, sonst ist der Countdown irreführend.
- **Gesetzliches Widerrufsrecht nicht als Vorteil bewerben** („14 Tage Rückgabe!“ als USP ist unzulässig). Eine freiwillige Garantie kannst du unter `guarantee` vorbereiten.
- **Verkauf ab 18:** In den AGB steht, dass Messer nur an Volljährige verkauft werden. Entscheide, ob du das so willst.

---

## Instagram & TikTok

**Links immer mit UTM verwenden** – dann steht in jeder Stripe-Bestellung, woher sie kam:

```
https://DEINE-DOMAIN/?utm_source=instagram&utm_medium=bio&utm_campaign=bf26
https://DEINE-DOMAIN/?utm_source=instagram&utm_medium=story&utm_campaign=bf26&utm_content=reel-tomate
https://DEINE-DOMAIN/?utm_source=tiktok&utm_medium=video&utm_campaign=bf26&utm_content=zwiebel-test
https://DEINE-DOMAIN/?utm_source=creator&utm_medium=influencer&utm_campaign=bf26&utm_content=NAME
```

In Stripe siehst du das unter jeder Zahlung → *Metadaten*. Zusätzlich: Pro Creator einen eigenen Rabattcode anlegen.

**Pixel nachrüsten:** In `shop.config.json → tracking` die `metaPixelId` / `tiktokPixelId` eintragen. Cookie-Banner, Einwilligung und Events laufen automatisch. Danach Abschnitt 8 der Datenschutzerklärung ergänzen. Test: Seite mit `?debug=1` öffnen → alle Events in der Browser-Konsole.

**Hinweis:** Im Instagram-In-App-Browser wird Apple Pay oft nicht angezeigt. PayPal, Klarna und Karte funktionieren dort.

---

## Videos 🎬

**Was du drehen sollst, steht in [`VIDEO-DREHPLAN.md`](VIDEO-DREHPLAN.md).** Das sind 5 Clips mit Einstellung, Licht und Untertiteln.

1. Handy-Originale nach `assets/video/raw/` kopieren
2. `npm run videos` → macht automatisch kleine MP4s (Reels 720×1280, Hero 1080×1080) + Vorschaubilder (braucht ffmpeg)
3. In `shop.config.json → media` eintragen (Beispiel steht dort)

Der Player kann:
- Autoplay **nur** des sichtbaren Clips (spart mobiles Datenvolumen), Pause beim Wegscrollen
- **Untertitel im TikTok-Stil**, sekundengenau, `*Wort*` = orange hervorgehoben
- Ton-Button (immer nur ein Clip mit Ton), Fortschrittsbalken, Antippen = Pause
- Lädt Videos erst kurz bevor sie sichtbar werden; im Datensparmodus kein Autoplay

## Animationen

Alles ohne Zusatz-Bibliothek, flüssig auch auf älteren Handys:
Headline wird „aufgeschnitten“ · Lichtreflex wandert über die Klingen · Streichpreis wird durchgeschnitten, neuer Preis knallt rein · Zahlen zählen hoch · Laufband · Countdown-Ziffern klappen um · Messer gleiten ins Bild · Glanz auf den Kauf-Buttons · leichte 3D-Neigung am Desktop · schräge Schnittkanten zwischen Abschnitten.
Wer in den Systemeinstellungen „Bewegung reduzieren“ aktiviert hat, bekommt automatisch eine ruhige Version.

## Bilder austauschen

- Produktfotos: nach `assets/img/` legen und in `index.html` die `.svg`-Pfade ersetzen (Hero + Thumbnails + „Im Set“). Ideal: WebP/JPG, 1200 × 1200 px, < 200 KB. **Echte Fotos sind der größte Hebel gegen den „KI-Look“.**
- Stripe-Produktbild: `assets/img/product.png` ersetzen.
- Link-Vorschau: `assets/img/og.png` (1200 × 630) ersetzen.
- Wenn alles echt ist: `"showPlaceholders": false` in der Config.
- Bewertungen: nur echte in `reviews` eintragen.
- Kennzahlen (67 Lagen, 15°, 60 HRC) stehen in `index.html` im Abschnitt „Kennzahlen“. Bitte an dein echtes Produkt anpassen.

---

## Lokal testen

```bash
npm install
cp .env.example .env      # Stripe-Testschlüssel eintragen (oder leer lassen = Demo-Modus)
npm run dev               # → http://localhost:3000
npm run check             # Selbsttest der Shop-Logik (ohne Stripe-Konto)
```

## Dateien

```
shop.config.json        ← ALLE Preise, Texte, Bestand, Kampagne, Firmendaten
index.html              Landing Page
danke.html              Danke-Seite nach dem Kauf
vertrag-widerrufen.html Widerrufsbutton (Pflicht)
impressum / agb / widerrufsbelehrung / datenschutz / versand-zahlung .html
api/checkout.js         Erstellt Stripe-Checkout (Preis wird serverseitig berechnet)
api/stock.js            Echter Bestand aus Stripe
api/session.js          Bestelldaten für die Danke-Seite
api/stripe-webhook.js   Bestell-Mails
api/widerruf.js         Online-Widerruf + Eingangsbestätigung
assets/js/app.js        Countdown, Bundles, Sticky-Leiste, Checkout
assets/js/media.js      Hero-Video & Reels-Player mit Untertiteln
assets/js/fx.js         Scroll-Animationen, Zähler, 3D-Neigung
assets/video/           Deine komprimierten Clips (Originale in raw/, werden nicht hochgeladen)
assets/js/tracking.js   UTM, Consent-Banner, Meta/TikTok-Pixel (vorbereitet)
scripts/                Bilder erzeugen, Selbsttest
```
