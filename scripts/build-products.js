// npm run produkte – erzeugt die Produktseiten /produkte/<id>.html aus shop.config.json → catalog
// Nach jeder Änderung an Produkten, Preisen oder Bundles ausführen.
// Mit --check wird nur geprüft, ob die Seiten aktuell sind (für die Startprüfung).
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'produkte');
const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'shop.config.json'), 'utf8'));
const cat = cfg.catalog;
const site = (cfg.brand.siteUrl || '').replace(/\/$/, '');

const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const euro = (c) => (c / 100).toLocaleString('de-DE', { style: 'currency', currency: 'EUR', minimumFractionDigits: c % 100 ? 2 : 0 });
const product = (id) => cat.products.find((p) => p.id === id);
const bundlePrice = (b) => {
  if (Number.isInteger(b.price)) return b.price;
  let sum = 0;
  for (const id of b.items) { const p = product(id); if (!p || !Number.isInteger(p.price)) return null; sum += p.price; }
  return sum;
};
const priceText = (c) => (Number.isInteger(c) ? euro(c) : 'Preis folgt');
const img = (id, n) => `/assets/img/produkte/${id}/${n}.webp`;

const ICONS = {
  waves: '<path d="M3 8c2-1.6 4-1.6 6 0s4 1.6 6 0 4-1.6 6 0M3 12c2-1.6 4-1.6 6 0s4 1.6 6 0 4-1.6 6 0M3 16c2-1.6 4-1.6 6 0s4 1.6 6 0 4-1.6 6 0"/>',
  gem: '<path d="M6 4h12l3 5-9 11L3 9z"/><path d="M3 9h18M9 4l3 16 3-16M7.5 9 12 4l4.5 5"/>',
  gift: '<rect x="3" y="9" width="18" height="12" rx="1"/><path d="M2 9h20M12 9v12M12 9C10 4 6 4 6.5 6.5S12 9 12 9s5-.5 5.5-2.5S14 4 12 9"/>',
  shield: '<path d="M12 3 4 6v6c0 4.5 3.4 8.2 8 9 4.6-.8 8-4.5 8-9V6z"/><path d="m8.5 12 2.5 2.5 4.5-5"/>',
  box: '<path d="M21 8 12 3 3 8v8l9 5 9-5z"/><path d="m3 8 9 5 9-5M12 13v8"/>',
  truck: '<path d="M3 7h11v9H3zM14 10h4l3 3v3h-7z"/><circle cx="7" cy="18" r="2"/><circle cx="17" cy="18" r="2"/>',
  lock: '<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
  zoom: '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4M11 8v6M8 11h6"/>',
  rotate: '<path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/>',
};
const icon = (name) => `<svg class="ico" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name] || ''}</svg>`;

function header(p) {
  return `<header class="header pp-header" data-header>
    <div class="wrap header__inner">
      <a href="/" class="logo" aria-label="Kaspar – Startseite"><span class="logo__mark" aria-hidden="true"></span><span class="logo__text">Kaspar</span></a>
      <nav class="nav pp-nav" aria-label="Messer">
        ${cat.products.map((x) => `<a href="/produkte/${x.id}"${x.id === p.id ? ' class="is-active" aria-current="page"' : ''}>${esc(x.shortName)}</a>`).join('\n        ')}
      </nav>
      <button type="button" class="cart-btn" data-cart-open aria-label="Warenkorb öffnen">
        ${icon('box')}<span>Warenkorb</span><b class="cart-btn__count" data-cart-count hidden>0</b>
      </button>
    </div>
  </header>`;
}

function footer() {
  return `<footer class="footer">
    <div class="wrap footer__inner">
      <a href="/" class="logo logo--sm" aria-label="Kaspar – Startseite"><span class="logo__mark" aria-hidden="true"></span><span class="logo__text">Kaspar</span></a>
      <nav class="footer__links" aria-label="Messer">
        ${cat.products.map((x) => `<a href="/produkte/${x.id}">${esc(x.shortName)}</a>`).join('\n        ')}
      </nav>
      <nav class="footer__links" aria-label="Rechtliches">
        <a href="/impressum">Impressum</a><a href="/agb">AGB</a><a href="/widerrufsbelehrung">Widerrufsbelehrung</a><a href="/datenschutz">Datenschutz</a><a href="/versand-zahlung">Versand & Zahlung</a><a href="#" data-consent-open hidden>Cookie-Einstellungen</a>
      </nav>
      <a href="/vertrag-widerrufen" class="btn btn--small btn--ghost">Vertrag widerrufen</a>
      <p class="footer__copy">© ${new Date().getFullYear()} Kaspar · Alle Preise inkl. MwSt.</p>
    </div>
  </footer>`;
}

function bundleCard(b, currentId) {
  const total = bundlePrice(b);
  return `<article class="pp-bundle${b.items.includes(currentId) ? ' is-match' : ''}">
          <div class="pp-bundle__imgs">${b.items.map((id) => `<img src="${img(id, 1)}" alt="" width="1000" height="667" loading="lazy">`).join('')}</div>
          <div class="pp-bundle__body">
            <h3>${esc(b.name)}</h3>
            <p class="pp-bundle__tag">${esc(b.tagline)}</p>
            <ul class="pp-bundle__items">
              ${b.items.map((id) => { const x = product(id); return `<li><a href="/produkte/${id}">${esc(x.name)}</a><span data-price-of="${id}">${priceText(x.price)}</span></li>`; }).join('\n              ')}
            </ul>
            <p class="pp-bundle__total"><span>${Number.isInteger(b.price) ? 'Bundle-Preis' : 'Zusammen'}</span><strong data-bundle-price="${b.id}">${priceText(total)}</strong></p>
            <button type="button" class="btn btn--ghost btn--block" data-bundle-add="${b.id}"${total === null ? ' disabled' : ''}>Bundle in den Warenkorb</button>
          </div>
        </article>`;
}

function page(p) {
  const labels = cat.imageLabels;
  const images = [1, 2, 3, 4, 5].map((n, i) => ({ src: img(p.id, n), label: labels[i], alt: `${p.name} – ${labels[i]}` }));
  const sizes = [[1000, 667], [656, 437], [497, 331], [540, 360], [458, 305]];
  const others = cat.products.filter((x) => x.id !== p.id);
  const bundles = [...cat.bundles].sort((a, b) => (b.items.includes(p.id) ? 1 : 0) - (a.items.includes(p.id) ? 1 : 0));
  const hasPrice = Number.isInteger(p.price);
  const ld = {
    '@context': 'https://schema.org', '@type': 'Product', name: p.name, description: p.description.join(' '),
    brand: { '@type': 'Brand', name: 'KASPAR Damast' }, image: images.map((x) => site + x.src), sku: p.id,
    ...(hasPrice ? { offers: { '@type': 'Offer', priceCurrency: 'EUR', price: (p.price / 100).toFixed(2), availability: 'https://schema.org/InStock', url: `${site}/produkte/${p.id}` } } : {}),
  };
  const ship = cfg.shipping;

  return `<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <!-- Automatisch erzeugt von „npm run produkte“ – Änderungen bitte in shop.config.json → catalog -->
  <title>${esc(p.name)} – ${esc(p.tagline)}</title>
  <meta name="description" content="${esc(p.description[0])}">
  <meta name="theme-color" content="#ffffff">
  <link rel="canonical" href="${site}/produkte/${p.id}">
  <link rel="icon" href="/assets/img/favicon.svg" type="image/svg+xml">
  <meta property="og:type" content="product">
  <meta property="og:title" content="${esc(p.name)}">
  <meta property="og:description" content="${esc(p.tagline)} – mit Geschenkbox und Schutz-Noppen.">
  <meta property="og:image" content="/assets/img/produkte/${p.id}/og.jpg">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="preload" as="image" href="${images[0].src}">
  <link rel="stylesheet" href="/assets/css/style.css">
  <script type="application/ld+json">${JSON.stringify(ld)}</script>
  <script src="/assets/js/tracking.js" defer></script>
  <script src="/assets/js/cart.js" defer></script>
  <script src="/assets/js/product.js" defer></script>
</head>
<body class="pp-page" data-product="${p.id}">
  <a class="skip" href="#main">Zum Inhalt springen</a>
  ${header(p)}

  <main id="main">
    <nav class="wrap crumbs" aria-label="Brotkrumen">
      <a href="/">Start</a><span aria-hidden="true">/</span><span>Messer</span><span aria-hidden="true">/</span><span aria-current="page">${esc(p.shortName)}</span>
    </nav>

    <!-- ===== Produkt ===== -->
    <section class="wrap pp-top">
      <div class="pp-gallery" data-pp-gallery>
        <button type="button" class="pp-main" data-pp-open aria-label="Bild vergrößern">
          <img src="${images[0].src}" alt="${esc(images[0].alt)}" width="${sizes[0][0]}" height="${sizes[0][1]}" fetchpriority="high" data-pp-main>
          <span class="pp-main__hint">${icon('zoom').replace('class="ico"', 'class="ico ico--sm"')}<span>Vergrößern</span></span>
        </button>
        <div class="pp-thumbs" aria-label="Produktbilder">
          ${images.map((x, i) => `<button type="button" class="pp-thumb${i ? '' : ' is-active'}" data-pp-thumb="${i}" aria-label="${esc(x.label)}"${i ? '' : ' aria-current="true"'}><img src="${x.src}" alt="" width="${sizes[i][0]}" height="${sizes[i][1]}" loading="lazy"></button>`).join('\n          ')}
        </div>
        <script type="application/json" data-pp-images>${JSON.stringify(images.map((x, i) => ({ ...x, w: sizes[i][0], h: sizes[i][1] })))}</script>
      </div>

      <div class="pp-info">
        <h1 class="pp-title"><span class="pp-title__brand">KASPAR Damast</span> ${esc(p.shortName)}</h1>
        <p class="pp-tagline">${esc(p.tagline)}</p>

        <div class="pp-price">
          <strong data-pp-price>${priceText(p.price)}</strong>
          <span class="pp-price__note">inkl. MwSt. · zzgl. Versand${Number.isInteger(cat.freeShippingFromItems) ? `, ab ${cat.freeShippingFromItems} Messern versandkostenfrei` : ''}</span>
        </div>

        <ul class="pp-highlights">
          ${cat.highlights.map((h) => `<li>${icon(h.icon)}<span>${esc(h.text)}</span></li>`).join('\n          ')}
        </ul>

        <div class="pp-buy">
          <div class="qty" data-pp-qty>
            <button type="button" data-qty="-1" aria-label="Menge verringern">−</button>
            <input type="number" id="pp-qty" value="1" min="1" max="10" inputmode="numeric" aria-label="Menge">
            <button type="button" data-qty="1" aria-label="Menge erhöhen">+</button>
          </div>
          <button type="button" class="btn btn--primary btn--xl pp-add" data-pp-add${hasPrice ? '' : ' disabled'}>In den Warenkorb</button>
        </div>
        <button type="button" class="btn btn--ghost btn--block" data-pp-buy${hasPrice ? '' : ' disabled'}>Direkt kaufen</button>
        <p class="pp-soon" data-pp-soon${hasPrice ? ' hidden' : ''}>Preis und Verfügbarkeit folgen in Kürze.</p>
        <p class="error" role="alert" data-pp-error hidden></p>

        <ul class="pp-trust">
          <li>${icon('truck')}<span>Versand mit ${esc(ship.carrier)} in ${ship.deliveryDaysMin}–${ship.deliveryDaysMax} Werktagen</span></li>
          <li>${icon('lock')}<span>Sicher bezahlen: PayPal, Klarna, Karte, Apple Pay</span></li>
        </ul>

        <div class="pp-scope">
          <h2>${icon('box')} Lieferumfang</h2>
          <ul>${cat.inBox.map((x) => `<li>${esc(x)}</li>`).join('')}</ul>
        </div>
      </div>
    </section>

    <!-- ===== Beschreibung ===== -->
    <section class="section section--band" id="beschreibung">
      <div class="wrap pp-desc">
        <div class="pp-desc__text">
          <p class="eyebrow">Über das Messer</p>
          <h2 class="h2">${esc(p.shortName)}</h2>
          ${p.description.map((t) => `<p>${esc(t)}</p>`).join('\n          ')}
        </div>
        <dl class="pp-details">
          ${p.details.map((d) => `<div><dt>${esc(d.label)}</dt><dd>${esc(d.value)}</dd></div>`).join('\n          ')}
        </dl>
      </div>
    </section>

    <!-- ===== 360°-Ansicht: erscheint nur mit echtem 3D-Modell oder vollständiger 360°-Bildserie ===== -->
    <section class="section" id="ansicht-360" data-pp-3d hidden>
      <div class="wrap">
        <header class="section__head">
          <p class="eyebrow">Rundum-Ansicht</p>
          <h2 class="h2">Von allen Seiten ansehen</h2>
          <p class="section__lead">${icon('rotate').replace('class="ico"', 'class="ico ico--sm"')} Zum Drehen ziehen</p>
        </header>
        <div class="pp-3d" data-pp-3d-stage></div>
      </div>
    </section>

    <!-- ===== Verpackung & Zubehör ===== -->
    <section class="section" id="verpackung">
      <div class="wrap">
        <header class="section__head">
          <p class="eyebrow">Verpackung &amp; Zubehör</p>
          <h2 class="h2">Bereit zum Verschenken</h2>
          <p class="section__lead">Jedes Messer kommt in seiner schwarzen KASPAR-Präsentationsbox – mit Schutz-Noppen für die Klinge.</p>
        </header>
        <div class="pp-pack">
          <figure><button type="button" data-pp-open-index="3" aria-label="Bild vergrößern: ${esc(labels[3])}"><img src="${images[3].src}" alt="${esc(images[3].alt)}" width="${sizes[3][0]}" height="${sizes[3][1]}" loading="lazy"></button><figcaption>Geöffnet – das Messer sicher in der Box</figcaption></figure>
          <figure><button type="button" data-pp-open-index="4" aria-label="Bild vergrößern: ${esc(labels[4])}"><img src="${images[4].src}" alt="${esc(images[4].alt)}" width="${sizes[4][0]}" height="${sizes[4][1]}" loading="lazy"></button><figcaption>Geschlossen – mit Schutz-Noppen</figcaption></figure>
        </div>
      </div>
    </section>

    <!-- ===== Bundles ===== -->
    <section class="section section--band" id="bundles">
      <div class="wrap">
        <header class="section__head">
          <p class="eyebrow">Auch als Bundle</p>
          <h2 class="h2">Passende Kombinationen</h2>
        </header>
        <div class="pp-bundles">
        ${bundles.map((b) => bundleCard(b, p.id)).join('\n        ')}
        </div>
      </div>
    </section>

    <!-- ===== Weitere Messer ===== -->
    <section class="section" id="weitere">
      <div class="wrap">
        <header class="section__head">
          <p class="eyebrow">Die Serie</p>
          <h2 class="h2">Weitere KASPAR-Messer</h2>
        </header>
        <div class="pp-more">
          ${others.map((x) => `<a class="pp-card" href="/produkte/${x.id}"><img src="${img(x.id, 1)}" alt="${esc(x.name)}" width="1000" height="667" loading="lazy"><span class="pp-card__body"><strong>${esc(x.shortName)}</strong><span>${esc(x.tagline)}</span><b data-price-of="${x.id}">${priceText(x.price)}</b></span></a>`).join('\n          ')}
        </div>
      </div>
    </section>
  </main>

  ${footer()}

  <!-- Kaufleiste (mobil, erscheint beim Scrollen) -->
  <div class="sticky dark" data-pp-sticky aria-hidden="true">
    <div class="sticky__info"><strong>${esc(p.shortName)}</strong><span data-pp-price>${priceText(p.price)}</span></div>
    <button type="button" class="btn btn--primary" data-pp-add tabindex="-1"${hasPrice ? '' : ' disabled'}>In den Warenkorb</button>
  </div>
  <div class="toast" role="status" aria-live="polite" data-toast hidden></div>
</body>
</html>
`;
}

const check = process.argv.includes('--check');
fs.mkdirSync(OUT, { recursive: true });
let stale = 0;
for (const p of cat.products) {
  const file = path.join(OUT, p.id + '.html');
  const html = page(p).replace(/© \d{4}/, '© ' + new Date().getFullYear());
  if (check) {
    if (!fs.existsSync(file) || fs.readFileSync(file, 'utf8') !== html) { stale++; console.log('veraltet: produkte/' + p.id + '.html'); }
    continue;
  }
  fs.writeFileSync(file, html);
  console.log('✓ produkte/' + p.id + '.html');
}
if (check) process.exitCode = stale ? 1 : 0;
