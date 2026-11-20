/* ==========================================================================
   Casper Media – Hero-Video & Reels mit Untertiteln
   Clips in shop.config.json → "media" eintragen:
     "heroVideo": { "src": "/assets/video/hero.mp4", "poster": "/assets/video/hero.jpg" }
     "reels": [{ "src": "/assets/video/tomate.mp4", "poster": "/assets/video/tomate.jpg",
                 "title": "Tomaten-Test",
                 "captions": [{ "t": 0, "text": "Reife Tomate." }, { "t": 1.5, "text": "Kein Druck. *Einfach durch.*" }] }]
   *Sternchen* = orange hervorgehoben.
   ========================================================================== */
(function () {
  'use strict';
  if (!window.CasperConfig) return;

  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var saveData = !!(navigator.connection && navigator.connection.saveData);
  var T = function (e, d) { if (window.CasperTracking) window.CasperTracking.track(e, d); };

  var ICON = {
    muted: '<svg viewBox="0 0 24 24"><path d="M11 5 6 9H3v6h3l5 4z"/><path d="m22 9-6 6M16 9l6 6"/></svg>',
    sound: '<svg viewBox="0 0 24 24"><path d="M11 5 6 9H3v6h3l5 4z"/><path d="M15.5 8.5a5 5 0 0 1 0 7M18.5 5.5a9 9 0 0 1 0 13"/></svg>',
    play: '<svg viewBox="0 0 24 24"><path d="M7 4v16l13-8z"/></svg>',
  };

  // Platzhalter: zeigt dir, welche Clips du drehen solltest (siehe VIDEO-DREHPLAN.md)
  var TODO = [
    { title: 'Tomaten-Test', hint: '6–8 Sek. · Kochmesser gleitet ohne Druck durch eine reife Tomate. Nahaufnahme, Ton an.', caption: 'Kein Druck. *Einfach durch.*' },
    { title: 'Zwiebel in 20 Sek.', hint: '8–12 Sek. · Zwiebel würfeln, Zeitraffer erlaubt. Hände + Brett, von oben.', caption: 'Würfeln wie im *Restaurant.*' },
    { title: 'Auspacken', hint: '6–10 Sek. · Box öffnen, Messer rausziehen, Licht auf das Damastmuster.', caption: 'Das Geschenk, das man *jeden Tag* benutzt.' },
  ];

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtCaption(s) { return esc(s).replace(/\*(.+?)\*/g, '<mark>$1</mark>'); }

  window.CasperConfig.then(function (cfg) {
    var media = cfg.media || {};
    heroVideo(media.heroVideo);
    reels(media.reels || [], !!cfg.showPlaceholders);
  });

  // ---------------------------------------------------------------- Hero
  function heroVideo(v) {
    if (!v || !v.src) return;
    var main = document.querySelector('.gallery__main');
    if (!main) return;
    var img = main.querySelector('img');
    var vid = document.createElement('video');
    vid.muted = true; vid.loop = true; vid.playsInline = true;
    vid.setAttribute('muted', ''); vid.setAttribute('playsinline', '');
    vid.preload = 'auto';
    if (v.poster) vid.poster = v.poster;
    vid.setAttribute('aria-label', v.alt || 'Produktvideo');
    vid.addEventListener('loadeddata', function () { if (img) img.hidden = true; });
    vid.src = v.src;
    main.insertBefore(vid, img);
    if (!saveData && !reduce) vid.play().catch(function () {});
    var tag = main.querySelector('[data-placeholder]');
    if (tag) tag.hidden = true;
  }

  // ---------------------------------------------------------------- Reels
  function reels(list, placeholders) {
    var section = document.querySelector('[data-video-section]');
    var wrap = section && section.querySelector('[data-reels]');
    if (!wrap) return;
    var real = list.filter(function (r) { return r && r.src; });

    if (!real.length) {
      if (!placeholders) return;
      wrap.innerHTML = TODO.map(function (r) {
        return '<figure class="reel reel--todo" data-reveal>' +
          '<figcaption class="reel__label"><i></i>' + esc(r.title) + '</figcaption>' +
          '<div class="reel__todo"><b>Platzhalter – hier dein Clip</b>' + esc(r.hint) + '</div>' +
          '<div class="reel__shade"></div>' +
          '<p class="reel__caption">' + fmtCaption(r.caption) + '</p>' +
          '</figure>';
      }).join('');
      section.hidden = false;
      revealNow(wrap);
      return;
    }

    wrap.innerHTML = real.map(function (r, i) {
      return '<figure class="reel is-paused" data-reel="' + i + '" data-reveal>' +
        '<video muted playsinline loop preload="none"' + (r.poster ? ' poster="' + esc(r.poster) + '"' : '') +
        ' aria-label="' + esc(r.alt || r.title || 'Video') + '"></video>' +
        '<div class="reel__shade"></div>' +
        (r.title ? '<figcaption class="reel__label"><i></i>' + esc(r.title) + '</figcaption>' : '') +
        '<p class="reel__caption" aria-hidden="true"></p>' +
        '<button type="button" class="reel__play" tabindex="-1" aria-hidden="true">' + ICON.play + '</button>' +
        '<button type="button" class="reel__sound" aria-label="Ton einschalten">' + ICON.muted + '</button>' +
        '<div class="reel__progress"><span></span></div>' +
        '</figure>';
    }).join('');
    section.hidden = false;
    revealNow(wrap);

    var cards = Array.prototype.slice.call(wrap.querySelectorAll('[data-reel]'));
    cards.forEach(function (card) { setupReel(card, real[+card.getAttribute('data-reel')], cards); });
  }

  // Neu gerenderte Elemente sichtbar machen (fx.js lief schon)
  function revealNow(wrap) {
    var items = Array.prototype.slice.call(wrap.children);
    if (!('IntersectionObserver' in window) || reduce) { items.forEach(function (el) { el.classList.add('is-in'); }); return; }
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('is-in'); io.unobserve(e.target); } });
    }, { threshold: 0.1 });
    items.forEach(function (el, i) { el.style.setProperty('--d', i * 110 + 'ms'); io.observe(el); });
  }

  function setupReel(card, data, all) {
    var video = card.querySelector('video');
    var cap = card.querySelector('.reel__caption');
    var bar = card.querySelector('.reel__progress span');
    var soundBtn = card.querySelector('.reel__sound');
    var caps = (data.captions || []).slice().sort(function (a, b) { return a.t - b.t; });
    var current = null;
    var loaded = false;
    var userPaused = false;
    var started = false;

    if (!caps.length && data.caption) caps = [{ t: 0, text: data.caption }];

    function load() {
      if (loaded) return;
      loaded = true;
      video.src = data.src;
      video.preload = 'auto';
    }
    function setCaption(text) {
      if (text === current) return;
      current = text;
      cap.innerHTML = text ? fmtCaption(text) : '';
      cap.classList.remove('pop');
      void cap.offsetWidth;
      if (text) cap.classList.add('pop');
    }
    function play() {
      load();
      var p = video.play();
      if (p && p.catch) p.catch(function () { card.classList.add('is-paused'); });
    }

    video.addEventListener('play', function () {
      card.classList.remove('is-paused');
      if (!started) { started = true; T('VideoPlay', { content_name: data.title || data.src }); }
    });
    video.addEventListener('pause', function () { card.classList.add('is-paused'); });
    video.addEventListener('timeupdate', function () {
      var t = video.currentTime;
      if (video.duration) bar.style.width = (t / video.duration) * 100 + '%';
      var c = null;
      for (var i = 0; i < caps.length; i++) if (caps[i].t <= t) c = caps[i].text;
      setCaption(c);
    });

    // Antippen = Pause/Weiter
    video.addEventListener('click', function () {
      if (video.paused) { userPaused = false; play(); } else { userPaused = true; video.pause(); }
    });
    card.querySelector('.reel__play').addEventListener('click', function () { userPaused = false; play(); });

    // Ton: immer nur ein Video mit Ton
    soundBtn.addEventListener('click', function () {
      var turnOn = video.muted;
      all.forEach(function (other) {
        var v = other.querySelector('video');
        if (v !== video) { v.muted = true; other.querySelector('.reel__sound').innerHTML = ICON.muted; }
      });
      video.muted = !turnOn;
      soundBtn.innerHTML = turnOn ? ICON.sound : ICON.muted;
      soundBtn.setAttribute('aria-label', turnOn ? 'Ton ausschalten' : 'Ton einschalten');
      if (turnOn) { userPaused = false; play(); }
    });

    if (!('IntersectionObserver' in window)) { load(); return; }

    // Vorladen kurz bevor sichtbar, abspielen wenn zu 60 % sichtbar
    new IntersectionObserver(function (es) {
      if (es[0].isIntersecting) load();
    }, { rootMargin: '400px 0px' }).observe(card);

    new IntersectionObserver(function (es) {
      var e = es[0];
      if (e.intersectionRatio >= 0.6) {
        if (!userPaused && !saveData && !reduce) play();
      } else if (!video.paused) {
        video.pause();
      }
    }, { threshold: [0, 0.6] }).observe(card);
  }
})();
