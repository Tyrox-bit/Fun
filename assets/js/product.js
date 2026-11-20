/* ==========================================================================
   KASPAR Produktseite – Galerie, Vollbild-Ansicht, Menge, Kaufen,
   Bundles, 360°/3D-Ansicht (nur mit echten Daten), Kaufleiste.
   ========================================================================== */
(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var id = document.body.getAttribute('data-product');
  var images = JSON.parse(($('[data-pp-images]') || {}).textContent || '[]');
  var current = 0;
  var toastTimer;

  function euro(c) {
    return (c / 100).toLocaleString('de-DE', { style: 'currency', currency: 'EUR', minimumFractionDigits: c % 100 ? 2 : 0, maximumFractionDigits: 2 });
  }
  function toast(msg) {
    var el = $('[data-toast]');
    if (!el) return;
    el.textContent = msg;
    el.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { el.hidden = true; }, 5000);
  }

  // ---------------------------------------------------------------- Galerie
  function show(i) {
    current = (i + images.length) % images.length;
    var main = $('[data-pp-main]');
    var im = images[current];
    main.src = im.src;
    main.alt = im.alt;
    main.width = im.w;
    main.height = im.h;
    $$('[data-pp-thumb]').forEach(function (t, k) {
      t.classList.toggle('is-active', k === current);
      if (k === current) t.setAttribute('aria-current', 'true'); else t.removeAttribute('aria-current');
    });
  }
  $$('[data-pp-thumb]').forEach(function (t) {
    t.addEventListener('click', function () { show(parseInt(t.getAttribute('data-pp-thumb'), 10)); });
  });

  // ---------------------------------------------------------------- Vollbild
  var lb = null, lastFocus = null;
  function buildLightbox() {
    lb = document.createElement('div');
    lb.className = 'lightbox';
    lb.hidden = true;
    lb.setAttribute('role', 'dialog');
    lb.setAttribute('aria-modal', 'true');
    lb.setAttribute('aria-label', 'Produktbilder in groß');
    lb.innerHTML =
      '<button type="button" class="lightbox__x" data-lb-close aria-label="Schließen">✕</button>' +
      '<button type="button" class="lightbox__nav lightbox__nav--prev" data-lb-step="-1" aria-label="Vorheriges Bild">‹</button>' +
      '<figure class="lightbox__fig"><img alt="" data-lb-img><figcaption data-lb-cap></figcaption></figure>' +
      '<button type="button" class="lightbox__nav lightbox__nav--next" data-lb-step="1" aria-label="Nächstes Bild">›</button>';
    document.body.appendChild(lb);
    lb.addEventListener('click', function (e) {
      if (e.target.closest('[data-lb-close]') || e.target === lb) return closeLb();
      var s = e.target.closest('[data-lb-step]');
      if (s) step(parseInt(s.getAttribute('data-lb-step'), 10));
    });
    // Wischen auf dem Handy
    var x0 = null;
    lb.addEventListener('pointerdown', function (e) { x0 = e.clientX; });
    lb.addEventListener('pointerup', function (e) {
      if (x0 === null) return;
      var dx = e.clientX - x0;
      x0 = null;
      if (Math.abs(dx) > 50) step(dx < 0 ? 1 : -1);
    });
    document.addEventListener('keydown', function (e) {
      if (!lb || lb.hidden) return;
      if (e.key === 'Escape') closeLb();
      if (e.key === 'ArrowRight') step(1);
      if (e.key === 'ArrowLeft') step(-1);
    });
  }
  function paintLb() {
    var im = images[current];
    var img = $('[data-lb-img]', lb);
    img.src = im.src;
    img.alt = im.alt;
    $('[data-lb-cap]', lb).textContent = im.label + ' · ' + (current + 1) + ' / ' + images.length;
  }
  function step(d) { show(current + d); paintLb(); }
  function openLb(i) {
    if (!lb) buildLightbox();
    if (typeof i === 'number') show(i);
    lastFocus = document.activeElement;
    paintLb();
    lb.hidden = false;
    document.documentElement.classList.add('no-scroll');
    $('[data-lb-close]', lb).focus();
  }
  function closeLb() {
    lb.hidden = true;
    document.documentElement.classList.remove('no-scroll');
    if (lastFocus) lastFocus.focus();
  }
  var mainBtn = $('[data-pp-open]');
  if (mainBtn) mainBtn.addEventListener('click', function () { openLb(); });
  $$('[data-pp-open-index]').forEach(function (b) {
    b.addEventListener('click', function () { openLb(parseInt(b.getAttribute('data-pp-open-index'), 10)); });
  });

  // ---------------------------------------------------------------- Menge & Kaufen
  var qtyInput = $('#pp-qty');
  function qty() { return Math.max(1, Math.min(10, parseInt(qtyInput && qtyInput.value, 10) || 1)); }
  $$('[data-qty]').forEach(function (b) {
    b.addEventListener('click', function () { qtyInput.value = Math.max(1, Math.min(10, qty() + parseInt(b.getAttribute('data-qty'), 10))); });
  });
  if (qtyInput) qtyInput.addEventListener('change', function () { qtyInput.value = qty(); });

  $$('[data-pp-add]').forEach(function (b) {
    b.addEventListener('click', function () { if (window.KasparCart) window.KasparCart.add('product', id, qty()); });
  });
  var buy = $('[data-pp-buy]');
  if (buy) buy.addEventListener('click', function () {
    if (window.KasparCart) window.KasparCart.checkout([{ type: 'product', id: id, qty: qty() }], buy);
  });
  $$('[data-bundle-add]').forEach(function (b) {
    b.addEventListener('click', function () { if (window.KasparCart) window.KasparCart.add('bundle', b.getAttribute('data-bundle-add'), 1); });
  });

  // ---------------------------------------------------------------- Kaufleiste
  var sticky = $('[data-pp-sticky]');
  var buyBox = $('.pp-buy');
  if (sticky && buyBox && 'IntersectionObserver' in window) {
    new IntersectionObserver(function (es) {
      var show = !es[0].isIntersecting && es[0].boundingClientRect.top < 0;
      sticky.classList.toggle('is-visible', show);
      sticky.setAttribute('aria-hidden', show ? 'false' : 'true');
      $('button', sticky).tabIndex = show ? 0 : -1;
      document.body.style.setProperty('--sticky-h', show && innerWidth < 900 ? sticky.offsetHeight + 'px' : '0px');
    }).observe(buyBox);
  }

  // ---------------------------------------------------------------- 360° / 3D
  // Nur mit echten Daten: GLB-Modell (view3d.model) oder ≥ 24 Fotos rundum (view3d.spin).
  function setup3d(v) {
    var section = $('[data-pp-3d]');
    var stage = $('[data-pp-3d-stage]');
    if (!section || !stage || !v) return;
    if (v.model) {
      var s = document.createElement('script');
      s.type = 'module';
      s.src = 'https://cdn.jsdelivr.net/npm/@google/model-viewer@3.4.0/dist/model-viewer.min.js';
      document.head.appendChild(s);
      stage.innerHTML = '<model-viewer src="' + v.model + '" alt="3D-Modell" camera-controls touch-action="pan-y" auto-rotate shadow-intensity="0.6" exposure="1"' +
        (v.poster ? ' poster="' + v.poster + '"' : '') + ' style="width:100%;height:100%;background:transparent"></model-viewer>';
      section.hidden = false;
      return;
    }
    var frames = Array.isArray(v.spin) ? v.spin : [];
    if (frames.length < 24) return; // zu wenige Ansichten für eine echte Rundum-Ansicht
    var img = new Image();
    img.alt = 'Rundum-Ansicht – zum Drehen ziehen';
    img.src = frames[0];
    img.draggable = false;
    stage.appendChild(img);
    frames.forEach(function (f) { var p = new Image(); p.src = f; }); // vorladen
    var idx = 0, startX = null, startIdx = 0;
    stage.addEventListener('pointerdown', function (e) { startX = e.clientX; startIdx = idx; stage.setPointerCapture(e.pointerId); });
    stage.addEventListener('pointermove', function (e) {
      if (startX === null) return;
      var d = Math.round((e.clientX - startX) / (stage.clientWidth / frames.length) * 0.8);
      idx = ((startIdx - d) % frames.length + frames.length) % frames.length;
      img.src = frames[idx];
    });
    stage.addEventListener('pointerup', function () { startX = null; });
    stage.setAttribute('tabindex', '0');
    stage.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') { idx = (idx + (e.key === 'ArrowRight' ? 1 : -1) + frames.length) % frames.length; img.src = frames[idx]; }
    });
    section.hidden = false;
  }

  // ---------------------------------------------------------------- Aktuelle Preise aus der Config
  if (window.KasparConfig) window.KasparConfig.then(function (cfg) {
    var products = cfg.catalog.products;
    var p = products.find(function (x) { return x.id === id; });
    if (!p) return;
    var priced = Number.isInteger(p.price);
    $$('[data-pp-price]').forEach(function (el) { el.textContent = priced ? euro(p.price) : 'Preis folgt'; });
    $$('[data-pp-add], [data-pp-buy]').forEach(function (b) { b.disabled = !priced; });
    var soon = $('[data-pp-soon]'); if (soon) soon.hidden = priced;
    $$('[data-price-of]').forEach(function (el) {
      var x = products.find(function (q) { return q.id === el.getAttribute('data-price-of'); });
      el.textContent = x && Number.isInteger(x.price) ? euro(x.price) : 'Preis folgt';
    });
    cfg.catalog.bundles.forEach(function (b) {
      var total = Number.isInteger(b.price) ? b.price : b.items.reduce(function (s, pid) {
        var x = products.find(function (q) { return q.id === pid; });
        return s === null || !x || !Number.isInteger(x.price) ? null : s + x.price;
      }, 0);
      var el = $('[data-bundle-price="' + b.id + '"]'); if (el) el.textContent = total === null ? 'Preis folgt' : euro(total);
      var btn = $('[data-bundle-add="' + b.id + '"]'); if (btn) btn.disabled = total === null;
    });
    setup3d(p.view3d);
    // Black-Friday-Hinweis nur im Aktionszeitraum
    var promo = $('[data-pp-promo]');
    if (promo && cfg.campaign) {
      var now = Date.now();
      promo.hidden = !(now >= Date.parse(cfg.campaign.start) && now <= Date.parse(cfg.campaign.end));
    }
    if (window.KasparTracking) window.KasparTracking.track('ViewContent', { value: priced ? p.price / 100 : undefined, currency: 'EUR', content_ids: [id], content_name: p.name });
  });

  // Zurück vom abgebrochenen Checkout
  var params = new URLSearchParams(location.search);
  if (params.get('checkout') === 'abgebrochen') {
    setTimeout(function () { toast('Kein Stress – dein Warenkorb ist gespeichert.'); }, 500);
    history.replaceState(null, '', location.pathname + location.hash);
  }
})();
