/* ==========================================================================
   KASPAR Warenkorb – Einzelmesser + Bundles, gespeichert im Browser.
   Preise werden hier nur angezeigt; berechnet werden sie auf dem Server.
   API: KasparCart.add(type, id, qty) · .open() · .checkout(items?) · .count()
   ========================================================================== */
(function () {
  'use strict';
  var KEY = 'kaspar_cart_v1';
  var cfgPromise = fetch('/shop.config.json').then(function (r) { return r.json(); });
  window.KasparConfig = cfgPromise;
  var cfg = null;
  var items = load();
  var lastFocus = null;
  var T = function (e, d) { if (window.KasparTracking) window.KasparTracking.track(e, d); };

  function load() {
    try { var v = JSON.parse(localStorage.getItem(KEY) || '[]'); return Array.isArray(v) ? v : []; } catch (e) { return []; }
  }
  function save() { try { localStorage.setItem(KEY, JSON.stringify(items)); } catch (e) {} }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; });
  }
  function euro(c) {
    return (c / 100).toLocaleString('de-DE', { style: 'currency', currency: 'EUR', minimumFractionDigits: c % 100 ? 2 : 0, maximumFractionDigits: 2 });
  }

  // ---------------------------------------------------------------- Katalog
  function product(id) { return cfg && cfg.catalog.products.find(function (p) { return p.id === id; }); }
  function bundle(id) { return cfg && cfg.catalog.bundles.find(function (b) { return b.id === id; }); }
  function bundlePrice(b) {
    if (Number.isInteger(b.price)) return b.price;
    var sum = 0;
    for (var i = 0; i < b.items.length; i++) { var p = product(b.items[i]); if (!p || !Number.isInteger(p.price)) return null; sum += p.price; }
    return sum;
  }
  function info(it) {
    if (it.type === 'bundle') {
      var b = bundle(it.id); if (!b) return null;
      return { name: 'Bundle: ' + b.name, img: '/assets/img/produkte/' + b.items[0] + '/1.webp', price: bundlePrice(b), knives: b.items.length, href: '/produkte/' + b.items[0] + '#bundles' };
    }
    var p = product(it.id); if (!p) return null;
    return { name: p.name, img: '/assets/img/produkte/' + p.id + '/1.webp', price: Number.isInteger(p.price) ? p.price : null, knives: 1, href: '/produkte/' + p.id };
  }

  // ---------------------------------------------------------------- Aktionen
  function add(type, id, qty) {
    qty = Math.max(1, Math.min(10, parseInt(qty, 10) || 1));
    var ex = items.find(function (i) { return i.type === type && i.id === id; });
    if (ex) ex.qty = Math.min(10, ex.qty + qty); else items.push({ type: type, id: id, qty: qty });
    save();
    render();
    open();
    var inf = info({ type: type, id: id });
    if (inf) T('AddToCart', { value: inf.price ? (inf.price * qty) / 100 : undefined, currency: 'EUR', content_ids: [id], content_name: inf.name });
  }
  function setQty(type, id, qty) {
    items = items.map(function (i) { return i.type === type && i.id === id ? { type: type, id: id, qty: Math.max(0, Math.min(10, qty)) } : i; })
      .filter(function (i) { return i.qty > 0; });
    save();
    render();
  }
  function count() { return items.reduce(function (s, i) { return s + i.qty; }, 0); }

  function checkout(list, btn) {
    list = list || items;
    var err = document.querySelector('[data-cart-error]');
    var pageErr = document.querySelector('[data-pp-error]');
    [err, pageErr].forEach(function (e) { if (e) e.hidden = true; });
    if (btn) btn.classList.add('is-busy');
    var total = 0;
    list.forEach(function (it) { var inf = info(it); if (inf && inf.price) total += inf.price * it.qty; });
    T('InitiateCheckout', { value: total / 100, currency: 'EUR', content_ids: list.map(function (i) { return i.id; }) });
    return fetch('/api/checkout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        items: list.map(function (i) { return { type: i.type, id: i.id, qty: i.qty }; }),
        returnTo: document.body.getAttribute('data-product') || undefined,
        attribution: window.KasparTracking ? window.KasparTracking.getAttribution() : {},
      }),
    })
      .then(function (r) { return r.json().then(function (j) { return { ok: r.ok, body: j }; }); })
      .then(function (res) {
        if (res.ok && res.body.url) { window.location.href = res.body.url; return; }
        throw new Error(res.body.error || 'Unbekannter Fehler');
      })
      .catch(function (e) {
        if (btn) btn.classList.remove('is-busy');
        var target = isOpen() ? err : (pageErr || err);
        if (target) {
          target.textContent = e.message && e.message !== 'Failed to fetch' ? e.message : 'Verbindung fehlgeschlagen. Bitte versuch es nochmal.';
          target.hidden = false;
        }
      });
  }

  // ---------------------------------------------------------------- Oberfläche
  function build() {
    if (document.querySelector('[data-cart]')) return;
    var el = document.createElement('div');
    el.className = 'cart';
    el.setAttribute('data-cart', '');
    el.hidden = true;
    el.innerHTML =
      '<div class="cart__backdrop" data-cart-close></div>' +
      '<aside class="cart__panel" role="dialog" aria-modal="true" aria-labelledby="cart-title">' +
      '<header class="cart__head"><h2 id="cart-title">Warenkorb</h2><button type="button" class="cart__x" data-cart-close aria-label="Warenkorb schließen">✕</button></header>' +
      '<div class="cart__items" data-cart-items></div>' +
      '<footer class="cart__foot" data-cart-foot>' +
      '<p class="cart__ship" data-cart-ship></p>' +
      '<div class="cart__sum"><span>Zwischensumme</span><strong data-cart-total></strong></div>' +
      '<p class="cart__fine">inkl. MwSt. · Versand wird an der Kasse berechnet</p>' +
      '<button type="button" class="btn btn--primary btn--xl btn--block" data-cart-checkout>Zur Kasse</button>' +
      '<p class="error" role="alert" data-cart-error hidden></p>' +
      '</footer></aside>';
    document.body.appendChild(el);
    el.addEventListener('click', function (e) {
      if (e.target.closest('[data-cart-close]')) return close();
      var b = e.target.closest('[data-cart-qty]');
      if (b) {
        var row = b.closest('[data-cart-row]');
        var it = items.find(function (i) { return i.type + ':' + i.id === row.getAttribute('data-cart-row'); });
        if (it) setQty(it.type, it.id, it.qty + parseInt(b.getAttribute('data-cart-qty'), 10));
      }
      var c = e.target.closest('[data-cart-checkout]');
      if (c) checkout(null, c);
    });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && isOpen()) close(); });
  }

  function render() {
    $$('[data-cart-count]').forEach(function (b) { var n = count(); b.textContent = n; b.hidden = n === 0; });
    var list = document.querySelector('[data-cart-items]');
    if (!list || !cfg) return;
    var foot = document.querySelector('[data-cart-foot]');
    if (!items.length) {
      list.innerHTML = '<div class="cart__empty"><p>Dein Warenkorb ist leer.</p>' +
        cfg.catalog.products.map(function (p) { return '<a href="/produkte/' + p.id + '">' + esc(p.shortName) + ' ansehen</a>'; }).join('') + '</div>';
      foot.hidden = true;
      return;
    }
    foot.hidden = false;
    var total = 0, knives = 0, missing = false;
    list.innerHTML = items.map(function (it) {
      var inf = info(it);
      if (!inf) return '';
      knives += inf.knives * it.qty;
      if (inf.price === null) missing = true; else total += inf.price * it.qty;
      return '<div class="cart__row" data-cart-row="' + it.type + ':' + esc(it.id) + '">' +
        '<a href="' + inf.href + '" class="cart__img"><img src="' + inf.img + '" alt="" width="96" height="64"></a>' +
        '<div class="cart__meta"><a href="' + inf.href + '">' + esc(inf.name) + '</a>' +
        '<span>' + (inf.price === null ? 'Preis folgt' : euro(inf.price)) + '</span>' +
        '<div class="qty qty--sm"><button type="button" data-cart-qty="-1" aria-label="Menge verringern">−</button><output>' + it.qty + '</output><button type="button" data-cart-qty="1" aria-label="Menge erhöhen">+</button></div></div>' +
        '<strong class="cart__line">' + (inf.price === null ? '–' : euro(inf.price * it.qty)) + '</strong>' +
        '</div>';
    }).join('');
    document.querySelector('[data-cart-total]').textContent = missing ? 'Preis folgt' : euro(total);
    var from = cfg.catalog.freeShippingFromItems;
    var ship = document.querySelector('[data-cart-ship]');
    ship.textContent = Number.isInteger(from)
      ? (knives >= from ? '✓ Versandkostenfrei' : 'Noch ' + (from - knives) + ' Messer bis zum kostenlosen Versand')
      : '';
    var btn = document.querySelector('[data-cart-checkout]');
    btn.disabled = missing;
    btn.textContent = missing ? 'Preise folgen in Kürze' : 'Zur Kasse';
  }

  function isOpen() { var el = document.querySelector('[data-cart]'); return el && !el.hidden; }
  function open() {
    build();
    render();
    var el = document.querySelector('[data-cart]');
    lastFocus = document.activeElement;
    el.hidden = false;
    document.documentElement.classList.add('no-scroll');
    requestAnimationFrame(function () { el.classList.add('is-open'); el.querySelector('.cart__x').focus(); });
  }
  function close() {
    var el = document.querySelector('[data-cart]');
    if (!el) return;
    el.classList.remove('is-open');
    document.documentElement.classList.remove('no-scroll');
    setTimeout(function () { el.hidden = true; }, 200);
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }
  function $$(s) { return Array.prototype.slice.call(document.querySelectorAll(s)); }

  // Zurück vom Stripe-Checkout (Browser-Cache): Buttons wieder freigeben
  window.addEventListener('pageshow', function (e) { if (e.persisted) $$('.is-busy').forEach(function (b) { b.classList.remove('is-busy'); }); });
  // Warenkorb in anderem Tab geändert
  window.addEventListener('storage', function (e) { if (e.key === KEY) { items = load(); render(); } });

  document.addEventListener('click', function (e) {
    if (e.target.closest('[data-cart-open]')) { e.preventDefault(); open(); }
  });

  cfgPromise.then(function (c) {
    cfg = c;
    // Nicht mehr existierende Artikel aus altem Warenkorb entfernen
    items = items.filter(function (i) { return info(i); });
    save();
    build();
    render();
    if (window.KasparTracking) window.KasparTracking.init(cfg.tracking);
  });
  render();

  window.KasparCart = { add: add, open: open, checkout: checkout, count: count };
})();
