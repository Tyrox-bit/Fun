/* ==========================================================================
   Kaspar FX – Scroll-Animationen, Zähler, 3D-Neigung
   Respektiert „Bewegung reduzieren“ in den Systemeinstellungen.
   ========================================================================== */
(function () {
  'use strict';
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  // Kinder von [data-stagger] erscheinen nacheinander
  $$('[data-stagger]').forEach(function (group) {
    Array.prototype.forEach.call(group.children, function (child, i) {
      if (!child.hasAttribute('data-reveal')) child.setAttribute('data-reveal', '');
      child.style.setProperty('--d', Math.min(i * 90, 450) + 'ms');
    });
  });

  // Zahlen hochzählen
  function count(el) {
    if (el._counted) return;
    el._counted = true;
    var to = parseFloat(el.getAttribute('data-count')) || 0;
    if (reduce) { el.textContent = to; return; }
    var start = null;
    var dur = 1300;
    function step(t) {
      if (!start) start = t;
      var p = Math.min(1, (t - start) / dur);
      var eased = 1 - Math.pow(1 - p, 3);
      el.textContent = Math.round(to * eased);
      if (p < 1) requestAnimationFrame(step);
    }
    el.textContent = '0';
    requestAnimationFrame(step);
  }

  function activate(el) {
    el.classList.add('is-in');
    $$('[data-count]', el).forEach(count);
    if (el.hasAttribute('data-count')) count(el);
  }

  var targets = $$('[data-reveal], [data-fx], .stat');
  if (reduce || !('IntersectionObserver' in window)) {
    targets.forEach(activate);
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { activate(e.target); io.unobserve(e.target); }
      });
    }, { threshold: 0.15, rootMargin: '0px 0px -30px 0px' });
    targets.forEach(function (el) { io.observe(el); });
  }

  // Leichte 3D-Neigung des Produktbilds (nur Maus, nicht Touch)
  var tilt = document.querySelector('[data-tilt]');
  if (tilt && !reduce && window.matchMedia('(hover: hover) and (pointer: fine)').matches) {
    tilt.addEventListener('pointermove', function (e) {
      var r = tilt.getBoundingClientRect();
      var x = (e.clientX - r.left) / r.width - 0.5;
      var y = (e.clientY - r.top) / r.height - 0.5;
      tilt.style.setProperty('--ry', (x * 9).toFixed(2) + 'deg');
      tilt.style.setProperty('--rx', (-y * 9).toFixed(2) + 'deg');
    });
    tilt.addEventListener('pointerleave', function () {
      tilt.style.setProperty('--ry', '0deg');
      tilt.style.setProperty('--rx', '0deg');
    });
  }

  // ---------------------------------------------------------------- Orientierung
  // Fortschrittsbalken + aktiver Abschnitt (Navigation am Desktop, Name im Header mobil)
  var bar = document.querySelector('[data-progress]');
  var where = document.querySelector('[data-where]');
  var navLinks = $$('[data-nav]');
  var header = document.querySelector('[data-header]');
  var parallax = document.querySelector('[data-parallax]');
  var current = null;

  function sections() {
    return $$('[data-section]').filter(function (s) { return !s.hidden; });
  }
  // Navigationspunkte für ausgeblendete Abschnitte (z. B. noch keine Videos) verstecken
  function syncNav() {
    navLinks.forEach(function (a) {
      var target = document.getElementById(a.getAttribute('data-nav'));
      if (!a.classList.contains('btn')) a.hidden = !target || target.hidden;
    });
    var vl = document.querySelector('[data-video-link]');
    var vs = document.getElementById('videos');
    if (vl) vl.hidden = !vs || vs.hidden;
  }

  function update() {
    var doc = document.documentElement;
    var max = doc.scrollHeight - window.innerHeight;
    if (bar) bar.style.width = (max > 0 ? Math.min(100, (window.scrollY / max) * 100) : 0) + '%';

    // Aktiver Abschnitt = der, dessen Bereich die Linie knapp unter dem Header kreuzt
    var line = (header ? header.getBoundingClientRect().bottom : 0) + window.innerHeight * 0.25;
    var active = null;
    sections().forEach(function (s) {
      var r = s.getBoundingClientRect();
      if (r.top <= line && r.bottom > line) active = s;
    });
    if (!active) return;
    var id = active.id;
    if (id === current) return;
    current = id;
    navLinks.forEach(function (a) { a.classList.toggle('is-active', a.getAttribute('data-nav') === id); });
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
    requestAnimationFrame(function () {
      ticking = false;
      update();
      // Leichter Parallax-Effekt fürs Produktbild
      if (parallax && !reduce) {
        var y = Math.min(window.scrollY, 700);
        parallax.style.transform = 'translate3d(0,' + (y * 0.08).toFixed(1) + 'px,0) rotate(' + (y * -0.004).toFixed(2) + 'deg)';
      }
    });
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll);
  syncNav();
  update();
  // Videos werden nachträglich eingeblendet → Navigation nachziehen
  if ('MutationObserver' in window) {
    var vs = document.getElementById('videos');
    if (vs) new MutationObserver(function () { syncNav(); current = null; update(); }).observe(vs, { attributes: true, attributeFilter: ['hidden'] });
  }
})();
