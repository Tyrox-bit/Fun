// npm run check:launch – Startprüfung: Was fehlt noch bis zum Livegang?
// Prüft Config, Rechtstexte, Medien, .env und (falls online) die Live-Seite.
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
const cfg = JSON.parse(read('shop.config.json'));
const env = {};
if (fs.existsSync(path.join(ROOT, '.env'))) {
  for (const l of read('.env').split('\n')) { const m = l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)$/); if (m) env[m[1]] = m[2].replace(/^['"]|['"]$/g, ''); }
}

const c = { g: (s) => `\x1b[32m${s}\x1b[0m`, y: (s) => `\x1b[33m${s}\x1b[0m`, r: (s) => `\x1b[31m${s}\x1b[0m`, b: (s) => `\x1b[1m${s}\x1b[0m`, d: (s) => `\x1b[2m${s}\x1b[0m`, o: (s) => `\x1b[38;5;208m${s}\x1b[0m` };
const result = { ok: 0, warn: 0, block: 0 };
const ok = (s) => { result.ok++; console.log(c.g('  ✓ ') + s); };
const warn = (s, fix) => { result.warn++; console.log(c.y('  ⚠ ') + s + (fix ? c.d('\n      → ' + fix) : '')); };
const block = (s, fix) => { result.block++; console.log(c.r('  ✗ ') + s + (fix ? c.d('\n      → ' + fix) : '')); };
const head = (s) => console.log('\n' + c.b(s));
const todo = (v) => !v || /^\[.*\]$/.test(String(v));

(async () => {
  console.log('\n' + c.o('🔪 CASPER – STARTPRÜFUNG'));

  // ---------------------------------------------------------------- Firmendaten
  head('Firmendaten & Impressum');
  const L = cfg.legal;
  const missing = ['owner', 'street', 'zipCity', 'phone', 'email'].filter((k) => todo(L[k]));
  missing.length ? block('Firmendaten unvollständig: ' + missing.join(', '), 'npm run setup') : ok('Firmendaten vollständig');
  if (todo(L.vatId) && L.vatId) warn('USt-IdNr. enthält noch den Platzhalter', 'npm run setup (Enter = keine)');

  // ---------------------------------------------------------------- Rechtstexte
  head('Rechtstexte');
  const wb = read('widerrufsbelehrung.html');
  /class="todo"/.test(wb) || /Hier das amtliche Muster/.test(wb)
    ? block('Widerrufsbelehrung: amtliches Muster + Muster-Formular fehlen noch', 'Text aus Rechtstext-Generator (IT-Recht Kanzlei, Händlerbund …) in widerrufsbelehrung.html einfügen')
    : ok('Widerrufsbelehrung ersetzt');
  /Entwurf von Claude/.test(read('agb.html'))
    ? warn('AGB sind noch der Entwurf', 'Prüfen lassen bzw. durch Generator-Text ersetzen, dann den gelben Hinweis entfernen')
    : ok('AGB final');
  const ds = read('datenschutz.html');
  /Entwurf von Claude/.test(ds) ? warn('Datenschutzerklärung ist noch der Entwurf', 'Prüfen lassen, gelbe Stellen klären') : ok('Datenschutz final');
  if ((cfg.tracking.metaPixelId || cfg.tracking.tiktokPixelId) && /Derzeit nicht aktiv/.test(ds)) {
    block('Pixel sind aktiv, aber in der Datenschutzerklärung nicht beschrieben', 'Abschnitt 8 in datenschutz.html ergänzen');
  }

  // ---------------------------------------------------------------- Angebot
  head('Angebot & Preise');
  const now = Date.now();
  const start = Date.parse(cfg.campaign.start), end = Date.parse(cfg.campaign.end);
  end <= start ? block('Aktionsende liegt vor dem Start') : end < now ? warn('Aktion ist bereits beendet – Seite zeigt Normalpreise') : ok(`Aktion bis ${new Date(end).toLocaleString('de-DE', { timeZone: 'Europe/Berlin' })} Uhr`);
  cfg.bundles.forEach((b) => { if (b.salePrice >= b.compareAtPrice) warn(`${b.title}: Aktionspreis ist nicht günstiger als der Streichpreis`); });
  warn('Streichpreis = niedrigster Preis der letzten 30 Tage? (§ 11 PAngV)', 'Nur bestätigen, wenn das Set wirklich so verkauft wurde – sonst Streichpreis weglassen');
  ok(`Bestand: ${cfg.stock.totalSets} Sets`);

  // ---------------------------------------------------------------- Medien
  head('Fotos & Videos');
  const gal = (cfg.media && cfg.media.gallery) || [];
  gal.length ? ok(`${gal.length} Produktfoto(s)`) : block('Noch Platzhalter-Grafiken statt echter Fotos', 'Fotos nach assets/img/produkt/ legen → npm run medien');
  const reels = (cfg.media && cfg.media.reels) || [];
  reels.length ? ok(`${reels.length} Video(s)`) : warn('Keine Videos – stärkster Verkaufshebel fehlt', 'VIDEO-DREHPLAN.md → Clips nach assets/video/raw/ → npm run medien');
  reels.filter((r) => !r.captions || !r.captions.length).forEach((r) => warn(`Video „${r.title}“ hat keine Untertitel`, 'In shop.config.json → media.reels ergänzen'));
  cfg.showPlaceholders ? warn('Platzhalter-Hinweise sind noch eingeschaltet', 'shop.config.json → "showPlaceholders": false') : ok('Platzhalter ausgeschaltet');

  // ---------------------------------------------------------------- Verbindungen (.env)
  head('Verbindungen (lokale .env)');
  const key = env.STRIPE_SECRET_KEY || '';
  !key ? block('Kein Stripe-Schlüssel', 'npm run setup') : key.includes('_live_') ? ok('Stripe: LIVE-Schlüssel') : warn('Stripe: nur Test-Schlüssel', 'Für den Start: npm run setup mit sk_live_…');
  env.STRIPE_WEBHOOK_SECRET ? ok('Stripe-Webhook eingerichtet') : block('Stripe-Webhook fehlt (keine Bestellbestätigungen)', 'npm run setup');
  /^https:\/\//.test(env.SITE_URL || '') ? ok('Domain: ' + env.SITE_URL) : block('SITE_URL fehlt oder ist nicht https', 'npm run setup');
  env.RESEND_API_KEY && env.MAIL_FROM && env.SHOP_EMAIL ? ok('E-Mail-Versand eingerichtet') : block('E-Mail-Versand fehlt (Bestellbestätigung + Widerrufsbutton)', 'npm run setup');

  // ---------------------------------------------------------------- Live-Seite
  const site = env.SITE_URL || cfg.brand.siteUrl;
  if (site && /^https:/.test(site)) {
    head('Live-Seite ' + site);
    try {
      const ctl = new AbortController();
      const t = setTimeout(() => ctl.abort(), 8000);
      const h = await (await fetch(site + '/api/health', { signal: ctl.signal })).json();
      clearTimeout(t);
      h.stripe === 'live' ? ok('Server: Stripe LIVE') : h.stripe === 'test' ? warn('Server: Stripe im Test-Modus') : block('Server: kein Stripe-Schlüssel', 'Vercel → Environment Variables → .env einfügen → Redeploy');
      h.webhook ? ok('Server: Webhook-Secret gesetzt') : block('Server: Webhook-Secret fehlt', 'Vercel → Environment Variables');
      h.mail ? ok('Server: E-Mail eingerichtet') : block('Server: E-Mail fehlt', 'Vercel → Environment Variables');
      h.siteUrl ? ok('Server: SITE_URL gesetzt') : warn('Server: SITE_URL fehlt');
    } catch {
      warn('Live-Seite nicht erreichbar (noch nicht deployed?)', 'Vercel → Projekt importieren → Deploy');
    }
  }

  // ---------------------------------------------------------------- Fazit
  console.log('\n' + c.b('Ergebnis: ') + c.g(`${result.ok} ok`) + ' · ' + c.y(`${result.warn} Hinweise`) + ' · ' + c.r(`${result.block} blockierend`));
  console.log(result.block ? c.r('  → Noch nicht live gehen.\n') : c.g('  → Startklar! 🔥 Einmal echt kaufen und erstatten, dann Link in die Bio.\n'));
  process.exitCode = result.block ? 1 : 0;
})();
