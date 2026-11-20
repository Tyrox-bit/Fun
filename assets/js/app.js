/* ==========================================================================
   Kaspar Landing Page – Logik
   Inhalte/Preise kommen aus /shop.config.json, Bestand live aus /api/stock.
   ========================================================================== */
(function () {
  'use strict';

  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var T = function (e, d) { if (window.KasparTracking) window.KasparTracking.track(e, d); };
  var SEL_KEY = 'kaspar_bundle';

  // Config einmal laden – media.js & Co. nutzen dasselbe Promise
  var configPromise = fetch('/shop.config.json').then(function (r) { return r.json(); });
  window.KasparConfig = configPromise;

  var cfg = null;
  var stock = null;
  var clockOffset = 0; // Serverzeit − Browserzeit
  var selectedId = null;
  var saleActive = false;

  function now() { return Date.now() + clockOffset; }
  function euro(cents) {
    return (cents / 100).toLocaleString('de-DE', {
      style: 'currency', currency: 'EUR',
      minimumFractionDigits: cents % 100 ? 2 : 0, maximumFractionDigits: 2,
    });
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function setText(sel, text) { $$(sel).forEach(function (el) { el.textContent = text; }); }
  function bundle(id) { return cfg.bundles.find(function (b) { return b.id === id; }); }
  function priceOf(b) { return saleActive ? b.salePrice : b.compareAtPrice; }
  function shipOf(b) { return b.sets >= cfg.shipping.freeFromSets ? 0 : cfg.shipping.price; }
  function pct(b) { return Math.round((1 - b.salePrice / b.compareAtPrice) * 100); }
  function getLS(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function setLS(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }

  // ---------------------------------------------------------------- Kampagne
  function applyCampaign() {
    var t = now();
    saleActive = t >= Date.parse(cfg.campaign.start) && t <= Date.parse(cfg.campaign.end);
    document.body.classList.remove('is-loading');
    document.body.classList.toggle('is-sale', saleActive);
    document.body.classList.toggle('is-regular', !saleActive);
  }

  // ---------------------------------------------------------------- Inhalte
  function renderStatic() {
    var first = cfg.bundles[0];
    setText('[data-price-now]', euro(priceOf(first)));
    setText('[data-price-old]', euro(first.compareAtPrice));
    setText('[data-saving]', euro(first.compareAtPrice - first.salePrice));
    setText('[data-discount]', '−' + pct(first) + ' %');
    setText('[data-vat]', cfg.pricing.vatNote);
    setText('[data-stock-total]', cfg.stock.totalSets);
    $$('[data-stock-total][data-count]').forEach(function (el) { el.setAttribute('data-count', cfg.stock.totalSets); });
    setText('[data-carrier]', cfg.shipping.carrier);
    setText('[data-year]', new Date().getFullYear());

    var lowest = $('[data-lowest-note]');
    if (lowest) lowest.textContent = cfg.pricing.lowestPriceNote
      ? 'Streichpreis = niedrigster Preis der letzten 30 Tage vor Aktionsbeginn.' : '';

    var s = cfg.shipping;
    var shipText = s.price ? 'zzgl. ' + euro(s.price) + ' Versand · ab ' + s.freeFromSets + ' Sets gratis' : 'versandkostenfrei';
    setText('[data-shipping-note]', shipText);
    setText('[data-shipping-fine]', s.price ? 'Versand ' + euro(s.price) + ', ab ' + s.freeFromSets + ' Sets kostenlos' : 'Versand kostenlos');

    renderDelivery();
    renderSpecs();
    renderPayMethods();
    renderReviews();

    if (cfg.showPlaceholders) document.body.classList.add('show-placeholders');
  }

  function addBusinessDays(date, days) {
    var d = new Date(date);
    while (days > 0) {
      d.setDate(d.getDate() + 1);
      if (d.getDay() !== 0 && d.getDay() !== 6) days--;
    }
    return d;
  }
  function renderDelivery() {
    var fmt = function (d) { return d.toLocaleDateString('de-DE', { weekday: 'short', day: '2-digit', month: '2-digit' }); };
    var a = addBusinessDays(new Date(now()), cfg.shipping.deliveryDaysMin);
    var b = addBusinessDays(new Date(now()), cfg.shipping.deliveryDaysMax);
    setText('[data-delivery]', fmt(a) + ' – ' + fmt(b));
  }

  function renderSpecs() {
    var el = $('[data-specs]');
    if (!el) return;
    el.innerHTML = cfg.product.specs.map(function (s) {
      return '<div><dt>' + esc(s.label) + '</dt><dd>' + esc(s.value) + '</dd></div>';
    }).join('');
  }

  function renderPayMethods() {
    var html =
      '<span class="pm pm--paypal">Pay<b>Pal</b></span>' +
      '<span class="pm pm--klarna">Klarna.</span>' +
      '<span class="pm pm--apple">Apple Pay</span>' +
      '<span class="pm pm--google">G Pay</span>' +
      '<span class="pm pm--visa">VISA</span>' +
      '<span class="pm pm--mc" aria-label="Mastercard"><i></i><i></i></span>';
    $$('[data-paymethods]').forEach(function (el) { el.innerHTML = html; });
  }

  function renderReviews() {
    var list = (cfg.reviews || []).filter(function (r) { return r && r.text; });
    if (!list.length) return;
    var avg = list.reduce(function (s, r) { return s + (r.stars || 5); }, 0) / list.length;
    var stars = function (n) { return '★★★★★'.slice(0, Math.round(n)) + '☆☆☆☆☆'.slice(0, 5 - Math.round(n)); };
    $('[data-reviews]').innerHTML = list.map(function (r) {
      return '<article class="review"><div class="stars" aria-label="' + (r.stars || 5) + ' von 5 Sternen">' + stars(r.stars || 5) +
        '</div><p>' + esc(r.text) + '</p><footer>' + esc(r.name) + (r.verified ? ' · Verifizierter Kauf' : '') + '</footer></article>';
    }).join('');
    $('[data-reviews-section]').hidden = false;
    var rating = $('[data-rating]');
    rating.innerHTML = '<span class="stars">' + stars(avg) + '</span> ' + avg.toFixed(1).replace('.', ',') + ' aus ' + list.length + ' Bewertung' + (list.length > 1 ? 'en' : '');
    rating.hidden = false;
  }

  // ---------------------------------------------------------------- Bundles
  function renderBundles() {
    var wrap = $('[data-bundles]');
    if (!wrap) return;
    var remaining = stock ? stock.remainingSets : Infinity;
    wrap.innerHTML = cfg.bundles.map(function (b) {
      var p = priceOf(b);
      var disabled = b.sets > remaining;
      var per = b.sets > 1 ? euro(Math.round(p / b.sets)) + ' pro Set' : '';
      var ship = shipOf(b) === 0 ? 'Versand gratis' : '';
      var info = [per, ship].filter(Boolean).join(' · ');
      return '<label class="bundle' + (disabled ? ' is-disabled' : '') + '" data-bundle="' + b.id + '">' +
        (b.badge ? '<span class="bundle__flag">' + esc(b.badge) + '</span>' : '') +
        '<input type="radio" name="bundle" value="' + b.id + '"' + (disabled ? ' disabled' : '') + '>' +
        '<span class="bundle__radio" aria-hidden="true"></span>' +
        '<span><span class="bundle__title">' + esc(b.title) +
        (saleActive ? ' <span class="badge badge--soft">−' + euro(b.compareAtPrice - b.salePrice) + '</span>' : '') +
        '</span><span class="bundle__sub">' + esc(b.subtitle) + '</span>' +
        (info ? '<br><span class="bundle__per">' + info + '</span>' : '') + '</span>' +
        '<span class="bundle__price"><strong>' + euro(p) + '</strong>' +
        (saleActive ? '<s>' + euro(b.compareAtPrice) + '</s>' : '') + '</span>' +
        (disabled ? '<span class="sr-only">nicht mehr verfügbar</span>' : '') +
        '</label>';
    }).join('');

    // Auswahl: gespeichert > Standard > erstes verfügbares
    var candidates = [selectedId, getLS(SEL_KEY), cfg.defaultBundle].concat(cfg.bundles.map(function (b) { return b.id; }));
    var pick = candidates.find(function (id) { var b = id && bundle(id); return b && b.sets <= remaining; });
    select(pick || cfg.bundles[0].id, false);
  }

  function select(id, byUser) {
    var b = bundle(id);
    if (!b) return;
    selectedId = id;
    $$('[data-bundle]').forEach(function (el) {
      var on = el.getAttribute('data-bundle') === id;
      el.classList.toggle('is-selected', on);
      var input = $('input', el);
      if (input) input.checked = on;
    });
    var p = priceOf(b);
    setText('[data-checkout-label]', (soldOut() ? 'Ausverkauft' : 'Jetzt kaufen · ' + euro(p + shipOf(b))));
    setText('[data-sticky-title]', b.title + ' · Damast-Duo');
    setText('[data-sticky-price]', euro(p));
    setText('[data-sticky-old]', euro(b.compareAtPrice));

    var nudge = $('[data-shipping-nudge]');
    if (nudge) {
      var next = cfg.bundles.find(function (x) { return x.sets === b.sets + 1; });
      if (shipOf(b) > 0 && next) {
        nudge.textContent = '💡 Tipp: Mit ' + next.title + ' sparst du den Versand – das ' + next.sets + '. Set kostet nur ' + euro(priceOf(next) - p) + '.';
      } else if (shipOf(b) === 0) {
        nudge.textContent = '✓ Versandkostenfrei';
      } else {
        nudge.textContent = '';
      }
    }

    if (byUser) {
      setLS(SEL_KEY, id);
      T('AddToCart', { value: p / 100, currency: 'EUR', content_ids: [id], content_name: b.title });
    }
  }

  // ---------------------------------------------------------------- Bestand
  function soldOut() { return stock && stock.remainingSets <= 0; }

  function renderStock() {
    var total = cfg.stock.totalSets;
    var rem = stock ? stock.remainingSets : total;
    var text;
    if (!stock) text = 'Limitiert auf ' + total + ' Sets';
    else if (rem <= 0) text = 'Ausverkauft – danke für den Ansturm!';
    else if (rem <= Math.max(5, Math.round(total * 0.25))) text = 'Nur noch ' + rem + ' von ' + total + ' Sets verfügbar';
    else text = rem + ' von ' + total + ' Sets verfügbar';

    $$('[data-stock]').forEach(function (el) {
      el.classList.toggle('is-low', !!stock && rem <= Math.round(total * 0.25));
      el.classList.toggle('is-live', !!stock);
      $('[data-stock-text]', el).textContent = text;
      $('[data-stock-bar]', el).style.width = Math.max(4, (rem / total) * 100) + '%';
    });

    $$('[data-checkout]').forEach(function (btn) { btn.disabled = soldOut(); });
  }

  function fetchStock(first) {
    return fetch('/api/stock', { cache: 'no-store' })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (data) {
        if (data.serverTime) clockOffset = data.serverTime - Date.now();
        stock = data.demo ? null : data;
        applyCampaign();
        renderStock();
        renderBundles();
        if (first) maybeLastOrderToast();
      })
      .catch(function () { renderStock(); });
  }

  // Echte Info aus Stripe – keine erfundenen "XY hat gerade gekauft"-Popups.
  function maybeLastOrderToast() {
    if (!stock || !stock.lastOrderAt || getLS('kaspar_lot') === String(stock.lastOrderAt)) return;
    var mins = Math.round((now() - stock.lastOrderAt) / 60000);
    if (mins < 0 || mins > 360) return;
    setTimeout(function () {
      var when = mins < 2 ? 'gerade eben' : mins < 60 ? 'vor ' + mins + ' Minuten' : 'vor ' + Math.round(mins / 60) + ' Std.';
      toast('🔥 Letzte Bestellung: ' + when);
      setLS('kaspar_lot', String(stock.lastOrderAt));
    }, 7000);
  }

  // ---------------------------------------------------------------- Countdown
  var pad = function (n) { return (n < 10 ? '0' : '') + n; };
  function flipText(sel, text) {
    $$(sel).forEach(function (el) {
      if (el.textContent === text) return;
      el.textContent = text;
      el.classList.remove('flip');
      void el.offsetWidth;
      el.classList.add('flip');
    });
  }
  function tick() {
    var left = Date.parse(cfg.campaign.end) - now();
    if (saleActive && left <= 0) {
      applyCampaign();
      renderStatic();
      renderBundles();
      return;
    }
    if (!saleActive) return;
    var s = Math.floor(left / 1000);
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
    flipText('[data-cd="d"]', pad(d));
    flipText('[data-cd="h"]', pad(h));
    flipText('[data-cd="m"]', pad(m));
    flipText('[data-cd="s"]', pad(sec));
    var short = (d ? d + 'T ' : '') + pad(h) + ':' + pad(m) + ':' + pad(sec);
    setText('[data-countdown]', short);
  }

  // ---------------------------------------------------------------- Checkout
  function checkout(btn) {
    var b = bundle(selectedId);
    if (!b || soldOut()) return;
    var err = $('[data-checkout-error]');
    err.hidden = true;
    $$('[data-checkout]').forEach(function (x) { x.classList.add('is-busy'); });

    T('InitiateCheckout', { value: priceOf(b) / 100, currency: 'EUR', content_ids: [b.id], content_name: b.title });

    fetch('/api/checkout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        bundleId: b.id,
        attribution: window.KasparTracking ? window.KasparTracking.getAttribution() : {},
      }),
    })
      .then(function (r) { return r.json().then(function (j) { return { ok: r.ok, status: r.status, body: j }; }); })
      .then(function (res) {
        if (res.ok && res.body.url) {
          window.location.href = res.body.url;
          return;
        }
        if (res.status === 409) fetchStock();
        throw new Error(res.body.error || 'Unbekannter Fehler');
      })
      .catch(function (e) {
        $$('[data-checkout]').forEach(function (x) { x.classList.remove('is-busy'); });
        err.textContent = e.message && e.message !== 'Failed to fetch'
          ? e.message
          : 'Verbindung fehlgeschlagen. Bitte prüfe dein Internet und versuch es nochmal.';
        err.hidden = false;
        if (btn && btn.closest('[data-sticky]')) err.scrollIntoView({ behavior: 'smooth', block: 'center' });
      });
  }

  // ---------------------------------------------------------------- UI
  function toast(msg, ms) {
    var el = $('[data-toast]');
    el.textContent = msg;
    el.hidden = false;
    clearTimeout(toast._t);
    toast._t = setTimeout(function () { el.hidden = true; }, ms || 5000);
  }

  function initGallery() {
    var main = $('[data-gallery-main]');
    $$('.gallery__thumb').forEach(function (t) {
      t.addEventListener('click', function () {
        $$('.gallery__thumb').forEach(function (x) { x.classList.remove('is-active'); });
        t.classList.add('is-active');
        main.src = t.getAttribute('data-src');
      });
    });
  }

  function initSticky() {
    var bar = $('[data-sticky]');
    var heroCta = $('[data-hero-cta]');
    var offer = $('#angebot');
    if (!bar || !('IntersectionObserver' in window)) return;
    var heroVisible = true, heroAbove = false, offerVisible = false;
    function update() {
      var show = !heroVisible && heroAbove && !offerVisible;
      bar.classList.toggle('is-visible', show);
      bar.setAttribute('aria-hidden', show ? 'false' : 'true');
      $('button', bar).tabIndex = show ? 0 : -1;
      document.body.style.setProperty('--sticky-h', show && innerWidth < 900 ? bar.offsetHeight + 'px' : '0px');
    }
    new IntersectionObserver(function (e) {
      heroVisible = e[0].isIntersecting;
      heroAbove = e[0].boundingClientRect.top < 0;
      update();
    }).observe(heroCta);
    new IntersectionObserver(function (e) { offerVisible = e[0].isIntersecting; update(); }, { threshold: 0.15 }).observe(offer);
  }

  function bindEvents() {
    document.addEventListener('change', function (e) {
      if (e.target.name === 'bundle') select(e.target.value, true);
    });
    $$('[data-checkout]').forEach(function (btn) {
      btn.addEventListener('click', function () { checkout(btn); });
    });
    // Zurück vom Stripe-Checkout (Browser-Cache): Buttons wieder freigeben
    window.addEventListener('pageshow', function (e) {
      if (e.persisted) {
        $$('[data-checkout]').forEach(function (x) { x.classList.remove('is-busy'); });
        fetchStock();
      }
    });
    document.addEventListener('visibilitychange', function () {
      if (!document.hidden) { renderDelivery(); tick(); }
    });
  }

  function handleReturn() {
    var p = new URLSearchParams(location.search);
    if (p.get('checkout') === 'abgebrochen') {
      setTimeout(function () {
        toast(saleActive
          ? 'Kein Stress – deine Auswahl ist gespeichert. Das Angebot läuft noch ' + ($('[data-countdown]') || {}).textContent + '.'
          : 'Kein Stress – deine Auswahl ist gespeichert.', 7000);
      }, 600);
      p.delete('checkout');
      history.replaceState(null, '', location.pathname + (p.toString() ? '?' + p : '') + location.hash);
    }
  }

  // ---------------------------------------------------------------- Start
  configPromise
    .then(function (c) {
      cfg = c;
      applyCampaign();
      renderStatic();
      renderBundles();
      renderStock();
      tick();
      setInterval(tick, 1000);
      initGallery();
      initSticky();
      bindEvents();
      handleReturn();
      if (window.KasparTracking) window.KasparTracking.init(cfg.tracking);
      var first = cfg.bundles[0];
      T('ViewContent', { value: priceOf(first) / 100, currency: 'EUR', content_ids: [first.id], content_name: cfg.product.name });
      fetchStock(true);
      setInterval(fetchStock, 60000);
    })
    .catch(function (e) {
      console.error('Konfiguration konnte nicht geladen werden', e);
      document.body.classList.remove('is-loading');
      document.body.classList.add('is-sale');
    });
})();
