/* Setzt Firmendaten aus shop.config.json → "legal" in alle Rechtstexte ein.
   Werte in [eckigen Klammern] werden gelb markiert, bis du sie ausfüllst. */
(function () {
  fetch('/shop.config.json').then(function (r) { return r.json(); }).then(function (cfg) {
    var L = cfg.legal || {};
    var site = (cfg.brand && cfg.brand.siteUrl) || location.origin;
    var values = Object.assign({}, L, { site: site, siteHost: site.replace(/^https?:\/\//, '') });

    document.querySelectorAll('[data-legal]').forEach(function (el) {
      var v = values[el.getAttribute('data-legal')];
      if (v === undefined || v === null) return;
      el.textContent = v;
      if (/^\[.*\]$/.test(String(v))) el.classList.add('todo');
      if (el.tagName === 'A' && el.getAttribute('data-legal') === 'email') el.href = 'mailto:' + v;
    });

    document.querySelectorAll('[data-legal-vat]').forEach(function (el) {
      el.hidden = !L.vatId;
    });
    document.querySelectorAll('[data-if-kleinunternehmer]').forEach(function (el) {
      el.hidden = !L.kleinunternehmer;
    });
    document.querySelectorAll('[data-if-not-kleinunternehmer]').forEach(function (el) {
      el.hidden = !!L.kleinunternehmer;
    });
    document.querySelectorAll('[data-shipping-price]').forEach(function (el) {
      el.textContent = (cfg.shipping.price / 100).toLocaleString('de-DE', { style: 'currency', currency: 'EUR' });
    });
    document.querySelectorAll('[data-shipping-free]').forEach(function (el) { el.textContent = cfg.shipping.freeFromSets; });
    document.querySelectorAll('[data-shipping-days]').forEach(function (el) {
      el.textContent = cfg.shipping.deliveryDaysMin + '–' + cfg.shipping.deliveryDaysMax;
    });
    document.querySelectorAll('[data-carrier]').forEach(function (el) { el.textContent = cfg.shipping.carrier; });

    if (window.CasperTracking) window.CasperTracking.init(cfg.tracking);
  });
})();
