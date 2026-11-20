// npm run medien
// ---------------------------------------------------------------------------
// Bereitet deine Fotos & Videos automatisch für die Seite auf:
//
//   FOTOS  → assets/img/produkt/   (jpg, png, heic, webp – Reihenfolge = Dateiname)
//            Name enthält "koch"  → Bild für „Kochmesser“-Karte
//            Name enthält "schael"/"schäl" → Bild für „Schälmesser“-Karte
//            Alle Fotos landen in der Galerie oben (erstes = Hauptbild).
//   VIDEOS → assets/video/raw/     (mov, mp4)
//            Name beginnt mit "hero" → großes Video oben (quadratisch, ohne Ton)
//            Alle anderen → Reels mit Ton (Hochformat)
//
// Danach automatisch: verkleinert, Vorschaubilder, Link-Vorschau (og.png),
// Stripe-Produktbild (product.png) und Einträge in shop.config.json.
// Keine Installation nötig – ffmpeg & Bildwerkzeug werden beim ersten Start geladen.
// ---------------------------------------------------------------------------
const fs = require('fs');
const path = require('path');
const { execSync, spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const TOOLS = __dirname;
const P = (...p) => path.join(ROOT, ...p);
const IMG_IN = P('assets/img/produkt');
const IMG_OUT = P('assets/img/web');
const VID_IN = P('assets/video/raw');
const VID_OUT = P('assets/video');
const CONFIG = P('shop.config.json');

// ---- Werkzeuge beim ersten Mal installieren ----
if (!fs.existsSync(path.join(TOOLS, 'node_modules', 'sharp')) || !fs.existsSync(path.join(TOOLS, 'node_modules', 'ffmpeg-static'))) {
  console.log('Erster Start: lade Bild- & Videowerkzeuge (einmalig, ~1 Minute) …');
  execSync('npm install --no-audit --no-fund --loglevel=error', { cwd: TOOLS, stdio: 'inherit' });
}
const sharp = require(path.join(TOOLS, 'node_modules', 'sharp'));
const FFMPEG = require(path.join(TOOLS, 'node_modules', 'ffmpeg-static'));

for (const d of [IMG_IN, IMG_OUT, VID_IN, VID_OUT]) fs.mkdirSync(d, { recursive: true });

const cfg = JSON.parse(fs.readFileSync(CONFIG, 'utf8'));
cfg.media = cfg.media || {};

const slug = (f) => path.basename(f, path.extname(f)).toLowerCase()
  .replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue').replace(/ß/g, 'ss')
  .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const title = (s) => s.replace(/^\d+[-_ ]*/, '').replace(/-/g, ' ').replace(/^./, (c) => c.toUpperCase());
const natural = (a, b) => a.localeCompare(b, 'de', { numeric: true });
const fresh = (src, out) => fs.existsSync(out) && fs.statSync(out).mtimeMs > fs.statSync(src).mtimeMs;
const euro = (c) => (c / 100).toLocaleString('de-DE', { minimumFractionDigits: c % 100 ? 2 : 0 }) + ' €';
const xml = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function ffmpeg(args) {
  const r = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', ...args], { stdio: ['ignore', 'inherit', 'inherit'] });
  if (r.status !== 0) throw new Error('ffmpeg-Fehler bei: ' + args.join(' '));
}

(async () => {
  // ======================= FOTOS =======================
  const photos = fs.readdirSync(IMG_IN).filter((f) => /\.(jpe?g|png|webp|heic|heif|avif|tiff?)$/i.test(f)).sort(natural);
  if (photos.length) {
    console.log(`\n📷 ${photos.length} Foto(s) gefunden`);
    const gallery = [];
    const setImages = {};
    for (const f of photos) {
      const src = path.join(IMG_IN, f);
      const name = slug(f);
      const out = path.join(IMG_OUT, name + '.webp');
      if (!fresh(src, out)) {
        await sharp(src).rotate().resize({ width: 1400, height: 1400, fit: 'inside', withoutEnlargement: true })
          .webp({ quality: 80 }).toFile(out);
      }
      const kb = Math.round(fs.statSync(out).size / 1024);
      console.log(`   ✓ ${f} → assets/img/web/${name}.webp (${kb} KB)`);
      const url = '/assets/img/web/' + name + '.webp';
      const alt = /koch/.test(name) ? 'Casper Kochmesser 20 cm aus Damaststahl'
        : /scha?el|schal/.test(name) ? 'Casper Schälmesser 9 cm aus Damaststahl'
        : 'Casper Damast-Duo';
      gallery.push({ src: url, alt });
      if (/koch/.test(name) && !setImages.chef) setImages.chef = url;
      if (/scha?el|schal/.test(name) && !setImages.paring) setImages.paring = url;
    }
    cfg.media.gallery = gallery;
    cfg.media.setImages = setImages;

    // Fotos fest ins HTML schreiben (kein Aufblitzen der Platzhalter beim Laden)
    const INDEX = P('index.html');
    let html = fs.readFileSync(INDEX, 'utf8');
    const b0 = cfg.bundles[0];
    const pctTxt = '−' + Math.round((1 - b0.salePrice / b0.compareAtPrice) * 100) + ' %';
    const thumbs = gallery.map((g, i) =>
      `<button class="gallery__thumb${i ? '' : ' is-active'}" role="listitem" data-src="${g.src}" aria-label="Bild ${i + 1}: ${xml(g.alt)}"><img src="${g.src}" alt="" width="80" height="80" loading="lazy"></button>`
    ).join('\n              ');
    const block = `<!-- GALERIE:START – wird von „npm run medien“ automatisch erzeugt -->
          <div class="gallery" data-gallery data-photos>
            <div class="gallery__main" data-tilt>
              <span class="badge badge--sale hero__badge" data-sale-only><span data-discount>${pctTxt}</span></span>
              <img src="${gallery[0].src}" alt="${xml(gallery[0].alt)}" width="1400" height="1400" fetchpriority="high" data-gallery-main>
            </div>${gallery.length > 1 ? `
            <div class="gallery__thumbs" role="list">
              ${thumbs}
            </div>` : ''}
          </div>
          <!-- GALERIE:END -->`;
    html = html.replace(/<!-- GALERIE:START[\s\S]*?<!-- GALERIE:END -->/, block);
    for (const [key, alt] of [['chef', 'Kochmesser 20 cm'], ['paring', 'Schälmesser 9 cm']]) {
      if (!setImages[key]) continue;
      html = html.replace(new RegExp(`<img [^>]*data-set-img="${key}"[^>]*>`),
        `<img src="${setImages[key]}" alt="${alt}" width="1400" height="1050" loading="lazy" data-set-img="${key}" class="is-photo">`);
    }
    if (!html.includes('rel="preload" as="image"')) {
      html = html.replace('<link rel="stylesheet" href="/assets/css/style.css">',
        `<link rel="preload" as="image" href="${gallery[0].src}">\n  <link rel="stylesheet" href="/assets/css/style.css">`);
    } else {
      html = html.replace(/<link rel="preload" as="image" href="[^"]*">/, `<link rel="preload" as="image" href="${gallery[0].src}">`);
    }
    fs.writeFileSync(INDEX, html);
    console.log('   ✓ Galerie & „Im Set“-Bilder in index.html eingesetzt');

    // Stripe-Produktbild (quadratisch)
    const main = path.join(IMG_IN, photos[0]);
    await sharp(main).rotate().resize(1000, 1000, { fit: 'cover', position: 'attention' }).png({ compressionLevel: 9 })
      .toFile(P('assets/img/product.png'));
    console.log('   ✓ Stripe-Produktbild → assets/img/product.png');

    // Link-Vorschau für Instagram-DMs, WhatsApp & Co. (1200×630)
    const b1 = cfg.bundles[0];
    const pct = Math.round((1 - b1.salePrice / b1.compareAtPrice) * 100);
    const overlay = Buffer.from(`<svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg">
      <defs><linearGradient id="g" x1="0" x2="1"><stop offset="0" stop-color="#0a0a0b" stop-opacity=".95"/><stop offset=".55" stop-color="#0a0a0b" stop-opacity=".55"/><stop offset="1" stop-color="#0a0a0b" stop-opacity="0"/></linearGradient></defs>
      <rect width="1200" height="630" fill="url(#g)"/>
      <rect x="70" y="90" rx="26" width="400" height="56" fill="#ff3d3d"/>
      <text x="270" y="128" text-anchor="middle" font-family="Arial Black, Helvetica, Arial, sans-serif" font-weight="900" font-size="28" fill="#fff">${xml(cfg.campaign.headline)} · −${pct} %</text>
      <text x="70" y="270" font-family="Impact, Arial Black, Arial, sans-serif" font-weight="900" font-size="104" fill="#fff">${xml(cfg.product.name.toUpperCase())}</text>
      <text x="70" y="380" font-family="Impact, Arial Black, Arial, sans-serif" font-weight="900" font-size="80" fill="#ff7a1a">${xml(euro(b1.salePrice))}</text>
      <text x="${70 + euro(b1.salePrice).length * 44}" y="378" font-family="Arial, sans-serif" font-size="40" fill="#a8a29e" text-decoration="line-through">${xml(euro(b1.compareAtPrice))}</text>
      <text x="70" y="560" font-family="Impact, Arial Black, Arial, sans-serif" font-size="36" letter-spacing="8" fill="#d6d3d1">${xml(cfg.brand.name.toUpperCase())}</text>
    </svg>`);
    await sharp(main).rotate().resize(1200, 630, { fit: 'cover', position: 'attention' })
      .composite([{ input: overlay }]).png({ compressionLevel: 9 }).toFile(P('assets/img/og.png'));
    console.log('   ✓ Link-Vorschau → assets/img/og.png');
  } else {
    console.log('\n📷 Keine Fotos in assets/img/produkt/ – Platzhalter-Grafiken bleiben aktiv.');
  }

  // ======================= VIDEOS =======================
  const videos = fs.readdirSync(VID_IN).filter((f) => /\.(mov|mp4|m4v)$/i.test(f)).sort(natural);
  if (videos.length) {
    console.log(`\n🎬 ${videos.length} Video(s) gefunden`);
    const old = Object.fromEntries((cfg.media.reels || []).map((r) => [r.src, r]));
    const reels = [];
    for (const f of videos) {
      const src = path.join(VID_IN, f);
      const name = slug(f);
      const out = path.join(VID_OUT, name + '.mp4');
      const poster = path.join(VID_OUT, name + '.jpg');
      const isHero = name.startsWith('hero');
      if (!fresh(src, out)) {
        process.stdout.write(`   … ${f} wird komprimiert\r`);
        ffmpeg(isHero
          ? ['-i', src, '-t', '12', '-vf', 'scale=1080:1080:force_original_aspect_ratio=increase,crop=1080:1080,fps=30',
            '-c:v', 'libx264', '-preset', 'slow', '-crf', '27', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', out]
          : ['-i', src, '-t', '20', '-vf', 'scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,fps=30',
            '-c:v', 'libx264', '-preset', 'slow', '-crf', '26', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
            '-c:a', 'aac', '-b:a', '96k', '-ac', '2', out]);
        ffmpeg(['-ss', '0.5', '-i', out, '-frames:v', '1', '-q:v', '4', poster]);
      }
      const kb = Math.round(fs.statSync(out).size / 1024);
      console.log(`\r\x1b[K   ✓ ${f} → assets/video/${name}.mp4 (${kb} KB)${kb > 4000 ? '  ⚠ groß – Clip kürzen' : ''}`);
      const url = '/assets/video/' + name + '.mp4';
      if (isHero) {
        cfg.media.heroVideo = { src: url, poster: '/assets/video/' + name + '.jpg', alt: 'Casper Damast-Duo in Nahaufnahme' };
      } else {
        // Vorhandene Titel/Untertitel bleiben erhalten
        reels.push(old[url] || { src: url, poster: '/assets/video/' + name + '.jpg', title: title(name), captions: [] });
      }
    }
    cfg.media.reels = reels;
    const noCaps = reels.filter((r) => !r.captions || !r.captions.length);
    if (noCaps.length) console.log(`   💬 Tipp: Untertitel für ${noCaps.map((r) => r.title).join(', ')} in shop.config.json ergänzen (Beispiel in VIDEO-DREHPLAN.md).`);
  } else {
    console.log('\n🎬 Keine Videos in assets/video/raw/ – Video-Platzhalter bleiben aktiv.');
  }

  fs.writeFileSync(CONFIG, JSON.stringify(cfg, null, 2) + '\n');
  console.log('\n✅ shop.config.json aktualisiert. Vorschau: npm run dev → http://localhost:3000\n');
})().catch((e) => { console.error('\n✗', e.message); process.exit(1); });
