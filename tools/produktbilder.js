// npm run produktbilder -- <slug> [übersicht.png]
// ---------------------------------------------------------------------------
// Erzeugt die 5 Galeriebilder einer Produktseite in assets/img/produkte/<slug>/:
//   1.webp Hauptfoto · 2.webp Schrägansicht · 3.webp Griff/Rückansicht
//   4.webp Box geöffnet · 5.webp Box geschlossen + Schutz-Noppen · og.jpg (Link-Vorschau)
//
// Variante A – Originalfotos (empfohlen, beste Qualität):
//   Fotos als 1.jpg … 5.jpg nach assets/img/produkte-original/<slug>/ legen, dann:
//   npm run produktbilder -- chefmesser
//
// Variante B – aus einer Produktübersicht im KASPAR-Layout ausschneiden
//   (Schrift, Icons und Rahmen werden NICHT übernommen):
//   npm run produktbilder -- chefmesser pfad/zur/uebersicht.png
//
// Alle Bilder bekommen dasselbe Seitenverhältnis (3:2) auf ihrem eigenen
// Hintergrundton, damit die Galerie ruhig und einheitlich wirkt.
// ---------------------------------------------------------------------------
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

const [slug, sheet] = process.argv.slice(2);
if (!slug || !/^[a-z0-9-]+$/.test(slug)) {
  console.log('Aufruf: npm run produktbilder -- <slug> [übersicht.png]   (slug z. B. chefmesser)');
  process.exit(1);
}
const OUT = path.join(ROOT, 'assets/img/produkte', slug);
fs.mkdirSync(OUT, { recursive: true });

// Bildbereiche im KASPAR-Übersichtslayout (Referenzgröße 1055 × 1491)
const REF = { w: 1055, h: 1491 };
const AREAS = [
  { left: 30, top: 355, width: 1000, height: 195 },  // 1 Hauptfoto
  { left: 18, top: 591, width: 656, height: 331 },   // 2 Schrägansicht
  { left: 700, top: 591, width: 336, height: 331 },  // 3 Griff / Rückansicht
  { left: 22, top: 950, width: 540, height: 268 },   // 4 Box geöffnet
  { left: 588, top: 968, width: 458, height: 256 },  // 5 Box geschlossen + Noppen
];
const RATIO = 3 / 2;

// Hellste Ecke = Hintergrundton (Fotos liegen auf hellem Grund)
async function backgroundOf(buf) {
  const img = sharp(buf);
  const { width, height } = await img.metadata();
  const s = 6;
  const corners = [[0, 0], [width - s, 0], [0, height - s], [width - s, height - s]];
  let best = null;
  for (const [left, top] of corners) {
    const { data } = await sharp(buf).extract({ left, top, width: s, height: s }).raw().toBuffer({ resolveWithObject: true });
    let r = 0, g = 0, b = 0, n = 0;
    for (let i = 0; i < data.length; i += 3) { r += data[i]; g += data[i + 1]; b += data[i + 2]; n++; }
    const c = { r: Math.round(r / n), g: Math.round(g / n), b: Math.round(b / n) };
    if (!best || c.r + c.g + c.b > best.r + best.g + best.b) best = c;
  }
  return best;
}

// Auf einheitliches Seitenverhältnis bringen, ohne zu beschneiden oder hochzurechnen
async function toGallery(buf, outFile, maxW = 1600) {
  const meta = await sharp(buf).metadata();
  let w = meta.width, h = meta.height;
  if (w > maxW) { buf = await sharp(buf).resize({ width: maxW }).toBuffer(); h = Math.round(h * maxW / w); w = maxW; }
  const bg = await backgroundOf(buf);
  let W = w, H = Math.round(w / RATIO);
  if (H < h) { H = h; W = Math.round(h * RATIO); }
  const left = Math.floor((W - w) / 2), top = Math.floor((H - h) / 2);
  await sharp(buf).extend({ left, right: W - w - left, top, bottom: H - h - top, background: bg })
    .webp({ quality: 86 }).toFile(outFile);
  return { W, H, bg };
}

(async () => {
  const sources = [];
  if (sheet) {
    const m = await sharp(sheet).metadata();
    const sx = m.width / REF.w, sy = m.height / REF.h;
    for (const a of AREAS) {
      sources.push(await sharp(sheet).extract({
        left: Math.round(a.left * sx), top: Math.round(a.top * sy),
        width: Math.round(a.width * sx), height: Math.round(a.height * sy),
      }).png().toBuffer());
    }
    console.log(`Übersicht ${m.width}×${m.height} → 5 Ausschnitte`);
  } else {
    const dir = path.join(ROOT, 'assets/img/produkte-original', slug);
    if (!fs.existsSync(dir)) { console.log('Keine Originale in ' + path.relative(ROOT, dir) + ' und keine Übersicht angegeben.'); process.exit(1); }
    for (let i = 1; i <= 5; i++) {
      const f = fs.readdirSync(dir).find((x) => new RegExp(`^${i}\\.(jpe?g|png|webp|heic|tiff?)$`, 'i').test(x));
      if (!f) { console.log(`Fehlt: ${i}.jpg in ${path.relative(ROOT, dir)}`); process.exit(1); }
      sources.push(await sharp(path.join(dir, f)).rotate().toBuffer());
    }
  }

  for (let i = 0; i < 5; i++) {
    const { W, H } = await toGallery(sources[i], path.join(OUT, `${i + 1}.webp`));
    const kb = Math.round(fs.statSync(path.join(OUT, `${i + 1}.webp`)).size / 1024);
    console.log(`  ✓ ${i + 1}.webp  ${W}×${H}  ${kb} KB${W < 900 ? '  (klein – für scharfen Zoom Originalfoto verwenden)' : ''}`);
  }

  // Link-Vorschau (Instagram-DM, WhatsApp …): Hauptfoto auf 1200×630
  const main = sources[0];
  const bg = await backgroundOf(main);
  const fitted = await sharp(main).resize({ width: 1080, height: 520, fit: 'inside', withoutEnlargement: false }).toBuffer();
  const fm = await sharp(fitted).metadata();
  await sharp({ create: { width: 1200, height: 630, channels: 3, background: bg } })
    .composite([{ input: fitted, left: Math.round((1200 - fm.width) / 2), top: Math.round((630 - fm.height) / 2) }])
    .jpeg({ quality: 84, mozjpeg: true }).toFile(path.join(OUT, 'og.jpg'));
  console.log('  ✓ og.jpg   1200×630');
  console.log(`\nFertig: assets/img/produkte/${slug}/ – danach npm run produkte`);
})().catch((e) => { console.error('✗', e.message); process.exit(1); });
