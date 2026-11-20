// npm run duo-bild – baut aus den Produktfotos der Messer im Aktions-Set
// (shop.config.json → product.items) die Bilder der Aktionsseite:
//   assets/img/duo.webp     Hauptbild (beide Messer übereinander, echte Fotos)
//   assets/img/product.png  Produktbild im Stripe-Checkout
//   assets/img/og.png       Link-Vorschau (Instagram-DM, WhatsApp …)
// Nach neuen Produktfotos einmal npm run duo-bild starten.
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const TOOLS = __dirname;
const ROOT = path.join(TOOLS, '..');
if (!fs.existsSync(path.join(TOOLS, 'node_modules', 'sharp'))) {
  console.log('Erster Start: lade Bildwerkzeug (einmalig) …');
  execSync('npm install --no-audit --no-fund --loglevel=error', { cwd: TOOLS, stdio: 'inherit' });
}
const sharp = require(path.join(TOOLS, 'node_modules', 'sharp'));
const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'shop.config.json'), 'utf8'));
const ids = (cfg.product && cfg.product.items) || [];
if (ids.length < 1) { console.log('shop.config.json → product.items ist leer.'); process.exit(1); }

let BG = { r: 239, g: 239, b: 237 };
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const euro = (c) => (c / 100).toLocaleString('de-DE', { minimumFractionDigits: c % 100 ? 2 : 0 }) + ' €';

// Messer freistellen: Rand in Hintergrundfarbe abschneiden (Schatten bleibt)
async function knife(id) {
  const src = path.join(ROOT, 'assets/img/produkte', id, '1.webp');
  if (!fs.existsSync(src)) throw new Error('Fehlt: ' + path.relative(ROOT, src) + ' → erst npm run produktbilder -- ' + id);
  return sharp(src).trim({ threshold: 6 }).toBuffer();
}

(async () => {
  // Unveränderte Produktfotos als Streifen untereinander (wie auf den Übersichten) –
  // jeweils der mittlere Bereich mit dem Messer, keine Montage, kein Freistellen.
  const W = 1200;
  const strips = [];
  for (const id of ids) {
    const src = path.join(ROOT, 'assets/img/produkte', id, '1.webp');
    if (!fs.existsSync(src)) throw new Error('Fehlt: ' + path.relative(ROOT, src) + ' → erst npm run produktbilder -- ' + id);
    const full = await sharp(src).resize({ width: W }).toBuffer();
    const m = await sharp(full).metadata();
    const h = Math.round(m.height * 0.5);
    strips.push(await sharp(full).extract({ left: 0, top: Math.round((m.height - h) / 2), width: W, height: h }).toBuffer());
  }
  const H = strips.length * Math.round((await sharp(strips[0]).metadata()).height);
  const c0 = await sharp(strips[0]).extract({ left: 0, top: 0, width: 6, height: 6 }).stats();
  BG = { r: Math.round(c0.channels[0].mean), g: Math.round(c0.channels[1].mean), b: Math.round(c0.channels[2].mean) };
  const comps = strips.map((s, i) => ({ input: s, left: 0, top: i * Math.round(H / strips.length) }));
  const duo = await sharp({ create: { width: W, height: H, channels: 3, background: BG } }).composite(comps).png().toBuffer();
  await sharp(duo).webp({ quality: 88 }).toFile(path.join(ROOT, 'assets/img/duo.webp'));
  console.log('  ✓ assets/img/duo.webp');

  // Foto mit runden Ecken (wirkt als bewusst gerahmtes Bild auf jeder Fläche)
  async function framed(width) {
    const buf = await sharp(duo).resize({ width }).toBuffer();
    const m = await sharp(buf).metadata();
    const r = Math.round(width * 0.03);
    const mask = Buffer.from(`<svg width="${m.width}" height="${m.height}"><rect width="${m.width}" height="${m.height}" rx="${r}" fill="#fff"/></svg>`);
    return { buf: await sharp(buf).ensureAlpha().composite([{ input: mask, blend: 'dest-in' }]).png().toBuffer(), w: m.width, h: m.height };
  }

  const sq = await framed(920);
  await sharp({ create: { width: 1000, height: 1000, channels: 3, background: '#0b0c0e' } })
    .composite([{ input: sq.buf, left: 40, top: Math.round((1000 - sq.h) / 2) }])
    .png({ compressionLevel: 9 }).toFile(path.join(ROOT, 'assets/img/product.png'));
  console.log('  ✓ assets/img/product.png (Stripe-Checkout)');

  // Link-Vorschau mit Angebot
  const b1 = cfg.bundles[0];
  const pct = Math.round((1 - b1.salePrice / b1.compareAtPrice) * 100);
  const sideImg = await framed(600);
  const side = sideImg.buf;
  const text = Buffer.from(`<svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg">
    <rect width="560" height="630" fill="#0b0c0e"/>
    <rect x="56" y="96" rx="24" width="330" height="50" fill="#ef2b2b"/>
    <text x="221" y="130" text-anchor="middle" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="24" fill="#fff">${esc(cfg.campaign.headline)} · −${pct} %</text>
    <text x="56" y="232" font-family="Georgia, 'Times New Roman', serif" font-size="58" fill="#fff">KASPAR</text>
    <text x="58" y="268" font-family="Arial, sans-serif" font-size="20" letter-spacing="8" fill="#c9a26b">DAMAST-DUO</text>
    <text x="56" y="330" font-family="Arial, sans-serif" font-size="24" fill="#d4d4d2">Chefmesser + Officemesser</text>
    <text x="56" y="430" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="72" fill="#ff8a3d">${esc(euro(b1.salePrice))}</text>
    <text x="${56 + euro(b1.salePrice).length * 42}" y="428" font-family="Arial, sans-serif" font-size="34" fill="#a3a39f" text-decoration="line-through">${esc(euro(b1.compareAtPrice))}</text>
    <text x="56" y="540" font-family="Arial, sans-serif" font-size="20" fill="#a3a39f">Limitiert auf ${cfg.stock.totalSets} Sets · je in Geschenkbox</text>
  </svg>`);
  await sharp({ create: { width: 1200, height: 630, channels: 3, background: '#0b0c0e' } })
    .composite([{ input: side, left: 560, top: Math.round((630 - sideImg.h) / 2) }, { input: text, left: 0, top: 0 }])
    .png({ compressionLevel: 9 }).toFile(path.join(ROOT, 'assets/img/og.png'));
  console.log('  ✓ assets/img/og.png (Link-Vorschau)');
})().catch((e) => { console.error('✗', e.message); process.exit(1); });
