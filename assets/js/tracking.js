/* ==========================================================================
   Casper Tracking – vorbereitet für Meta- und TikTok-Pixel.
   AKTIVIEREN: Pixel-ID in shop.config.json → "tracking" eintragen. Fertig.
   - Cookie-Banner erscheint dann automatisch
   - Pixel laden erst NACH Einwilligung (DSGVO/TDDDG)
   - Events: PageView, ViewContent, AddToCart, InitiateCheckout, Purchase
   Zusätzlich (ohne Cookies): UTM-Parameter werden gemerkt und an Stripe
   übergeben – so siehst du in jeder Bestellung, ob sie von Instagram oder
   TikTok kam.
   ========================================================================== */
(function () {
  'use strict';
  var CONSENT_KEY = 'casper_consent_v1';
  var ATTR_KEY = 'casper_attr_v1';
  var queue = [];
  var ready = false;
  var initialized = false;
  var cfg = { metaPixelId: '', tiktokPixelId: '' };

  function store(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }
  function load(k) { try { return JSON.parse(localStorage.getItem(k) || 'null'); } catch (e) { return null; } }

  // ---- Attribution (UTM, Klick-IDs) ----
  // Ohne Einwilligung nur im Arbeitsspeicher (reicht für den Kauf im selben Besuch).
  // Mit Marketing-Einwilligung 30 Tage gespeichert (erster Kontakt zählt).
  var attr = {};
  function captureAttribution() {
    var p = new URLSearchParams(location.search);
    var keys = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'fbclid', 'ttclid'];
    keys.forEach(function (k) { if (p.get(k)) attr[k] = p.get(k).slice(0, 200); });
    // Instagram/TikTok-In-App-Browser erkennen, falls keine UTM gesetzt ist
    var ua = navigator.userAgent || '';
    if (!attr.utm_source) {
      if (/Instagram/i.test(ua)) attr.utm_source = 'instagram-app';
      else if (/musical_ly|TikTok|Bytedance/i.test(ua)) attr.utm_source = 'tiktok-app';
      else if (/FBAN|FBAV/i.test(ua)) attr.utm_source = 'facebook-app';
    }
    if (Object.keys(attr).length) {
      attr.landing = location.pathname;
      if (document.referrer) attr.referrer = document.referrer.slice(0, 200);
    }
  }
  function persistAttribution() {
    var c = consent();
    if (!c || !c.marketing) return;
    var existing = load(ATTR_KEY);
    var fresh = existing && Date.now() - existing.t < 30 * 864e5;
    if (Object.keys(attr).length && !fresh) store(ATTR_KEY, { t: Date.now(), d: attr });
  }
  function getAttribution() {
    if (Object.keys(attr).length) return attr;
    var c = consent();
    var a = c && c.marketing ? load(ATTR_KEY) : null;
    return a && a.d ? a.d : {};
  }

  // ---- Einwilligung ----
  function hasTrackers() { return Boolean(cfg.metaPixelId || cfg.tiktokPixelId); }
  function consent() { return load(CONSENT_KEY); }
  function setConsent(marketing) {
    store(CONSENT_KEY, { marketing: !!marketing, t: Date.now() });
    hideBanner();
    if (marketing) { persistAttribution(); loadPixels(); }
    else { try { localStorage.removeItem(ATTR_KEY); } catch (e) {} }
  }

  function showBanner() {
    if (document.querySelector('.consent')) return;
    var el = document.createElement('div');
    el.className = 'consent';
    el.setAttribute('role', 'dialog');
    el.setAttribute('aria-label', 'Cookie-Einstellungen');
    el.innerHTML =
      '<h2>Kurz zu Cookies 🍪</h2>' +
      '<p>Wir nutzen Marketing-Cookies (Meta, TikTok), um zu messen, welche Werbung funktioniert. Nur mit deiner Zustimmung – du kannst sie jederzeit im Footer widerrufen. Mehr in der <a href="/datenschutz">Datenschutzerklärung</a>.</p>' +
      '<div class="consent__actions">' +
      '<button type="button" class="btn btn--ghost" data-c="0">Nur notwendige</button>' +
      '<button type="button" class="btn btn--ghost" data-c="1">Alle akzeptieren</button>' +
      '</div>';
    el.addEventListener('click', function (e) {
      var b = e.target.closest('[data-c]');
      if (b) setConsent(b.getAttribute('data-c') === '1');
    });
    document.body.appendChild(el);
  }
  function hideBanner() { var el = document.querySelector('.consent'); if (el) el.remove(); }

  // ---- Pixel laden (Standard-Snippets von Meta & TikTok) ----
  var loaded = false;
  function loadPixels() {
    if (loaded) return;
    loaded = true;
    if (cfg.metaPixelId) {
      /* eslint-disable */
      !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?n.callMethod.apply(n,arguments):n.queue.push(arguments)};if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';n.queue=[];t=b.createElement(e);t.async=!0;t.src=v;s=b.getElementsByTagName(e)[0];s.parentNode.insertBefore(t,s)}(window,document,'script','https://connect.facebook.net/en_US/fbevents.js');
      /* eslint-enable */
      window.fbq('init', cfg.metaPixelId);
    }
    if (cfg.tiktokPixelId) {
      /* eslint-disable */
      !function(w,d,t){w.TiktokAnalyticsObject=t;var ttq=w[t]=w[t]||[];ttq.methods=["page","track","identify","instances","debug","on","off","once","ready","alias","group","enableCookie","disableCookie","holdConsent","revokeConsent","grantConsent"];ttq.setAndDefer=function(t,e){t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)))}};for(var i=0;i<ttq.methods.length;i++)ttq.setAndDefer(ttq,ttq.methods[i]);ttq.instance=function(t){for(var e=ttq._i[t]||[],n=0;n<ttq.methods.length;n++)ttq.setAndDefer(e,ttq.methods[n]);return e};ttq.load=function(e,n){var r="https://analytics.tiktok.com/i18n/pixel/events.js";ttq._i=ttq._i||{};ttq._i[e]=[];ttq._i[e]._u=r;ttq._t=ttq._t||{};ttq._t[e]=+new Date;ttq._o=ttq._o||{};ttq._o[e]=n||{};var s=d.createElement("script");s.type="text/javascript";s.async=!0;s.src=r+"?sdkid="+e+"&lib="+t;var x=d.getElementsByTagName("script")[0];x.parentNode.insertBefore(s,x)}}(window,document,'ttq');
      /* eslint-enable */
      window.ttq.load(cfg.tiktokPixelId);
    }
    ready = true;
    queue.splice(0).forEach(function (e) { send(e[0], e[1]); });
  }

  // Event-Namen je Plattform
  var MAP = {
    PageView: { meta: 'PageView', tiktok: 'page' },
    ViewContent: { meta: 'ViewContent', tiktok: 'ViewContent' },
    AddToCart: { meta: 'AddToCart', tiktok: 'AddToCart' },
    InitiateCheckout: { meta: 'InitiateCheckout', tiktok: 'InitiateCheckout' },
    Purchase: { meta: 'Purchase', tiktok: 'CompletePayment' },
  };

  function send(event, data) {
    var m = MAP[event] || { meta: event, tiktok: event };
    data = data || {};
    var eventId = data.event_id; // für spätere Deduplizierung mit Conversions API
    var payload = {
      value: data.value, currency: data.currency || 'EUR',
      content_ids: data.content_ids, content_type: 'product', content_name: data.content_name,
    };
    if (window.fbq && cfg.metaPixelId) {
      if (m.meta === 'PageView') window.fbq('track', 'PageView');
      else window.fbq('track', m.meta, payload, eventId ? { eventID: eventId } : undefined);
    }
    if (window.ttq && cfg.tiktokPixelId) {
      if (m.tiktok === 'page') window.ttq.page();
      else window.ttq.track(m.tiktok, {
        value: payload.value, currency: payload.currency, content_type: 'product',
        contents: (payload.content_ids || []).map(function (id) { return { content_id: id, content_name: payload.content_name }; }),
      }, eventId ? { event_id: eventId } : undefined);
    }
  }

  function track(event, data) {
    // Debug: im Browser ?debug=1 anhängen, dann siehst du alle Events in der Konsole
    if (/[?&]debug=1/.test(location.search)) console.log('[track]', event, data || {});
    window.dispatchEvent(new CustomEvent('casper:track', { detail: { event: event, data: data } }));
    if (initialized && !hasTrackers()) return;
    if (ready) send(event, data); else queue.push([event, data]);
  }

  function init(trackingCfg) {
    if (initialized) return;
    initialized = true;
    cfg = Object.assign(cfg, trackingCfg || {});
    if (!hasTrackers()) { queue.length = 0; return; }
    var opener = document.querySelector('[data-consent-open]');
    if (opener) {
      opener.hidden = false;
      opener.addEventListener('click', function (e) { e.preventDefault(); showBanner(); });
    }
    var c = consent();
    if (c && c.marketing) { persistAttribution(); loadPixels(); }
    else if (!c) showBanner();
  }

  captureAttribution();
  window.CasperTracking = { init: init, track: track, getAttribution: getAttribution };
  track('PageView');
})();
