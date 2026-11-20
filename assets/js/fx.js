/* ==========================================================================
   Kaspar – Orientierung beim Scrollen
   Fortschrittsbalken + aktiver Abschnitt (Navigation am Desktop,
   Abschnittsname im Header auf dem Handy). Bewusst ohne Effekt-Animationen.
   ========================================================================== */
(function () {
  'use strict';
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var bar = document.querySelector('[data-progress]');
  var where = document.querySelector('[data-where]');
  var header = document.querySelector('[data-header]');
  var navLinks = $$('[data-nav]');
  var current = null;

  function sections() {
    return $$('[data-section]').filter(function (s) { return !s.hidden; });
  }

  // Navigationspunkte für ausgeblendete Abschnitte (z. B. noch keine Videos) verstecken
  function syncNav() {
    navLinks.forEach(function (a) {
      if (a.classList.contains('btn')) return;
      var target = document.getElementById(a.getAttribute('data-nav'));
      a.hidden = !target || target.hidden;
    });
  }

  function update() {
    var max = document.documentElement.scrollHeight - window.innerHeight;
    if (bar) bar.style.width = (max > 0 ? Math.min(100, (window.scrollY / max) * 100) : 0) + '%';

    var line = (header ? header.getBoundingClientRect().bottom : 0) + window.innerHeight * 0.25;
    var active = null;
    sections().forEach(function (s) {
      var r = s.getBoundingClientRect();
      if (r.top <= line && r.bottom > line) active = s;
    });
    if (!active || active.id === current) return;
    current = active.id;
    navLinks.forEach(function (a) { a.classList.toggle('is-active', a.getAttribute('data-nav') === current); });
    if (where) {
      where.textContent = active.getAttribute('data-section');
      where.classList.remove('pop');
      void where.offsetWidth;
      where.classList.add('pop');
    }
  }

  var ticking = false;
  function onScroll() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () { ticking = false; update(); });
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll);
  syncNav();
  update();

  // Videos werden erst eingeblendet, wenn echte Clips eingetragen sind → Navigation nachziehen
  var vs = document.getElementById('videos');
  if (vs && 'MutationObserver' in window) {
    new MutationObserver(function () { syncNav(); current = null; update(); })
      .observe(vs, { attributes: true, attributeFilter: ['hidden'] });
  }
})();
