/* =========================================================
   VILLA ALTAÏA — interactions
   GSAP + ScrollTrigger · Vanilla-Tilt · IntersectionObserver
   ========================================================= */
(function () {
  'use strict';

  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var isTouch = window.matchMedia('(hover: none)').matches;
  var hasGSAP = typeof window.gsap !== 'undefined';
  var hasST   = typeof window.ScrollTrigger !== 'undefined';
  var animate = hasGSAP && hasST && !reduced;

  // Les états initiaux masqués ne s'appliquent que si les animations tourneront.
  if (animate) document.documentElement.classList.add('is-ready');

  /* -------------------------------------------------------
     1. PHOTOGRAPHIES — URL Unsplash, lazy load, repli
     ------------------------------------------------------- */

  // Construit une URL Unsplash réelle à partir d'un identifiant de photo.
  function unsplash(id, w) {
    return 'https://images.unsplash.com/photo-' + id +
           '?auto=format&fit=crop&w=' + w + '&q=80';
  }

  // Largeur demandée en fonction de l'écran (évite de tirer 2000px sur mobile).
  function widthFor(img) {
    if (img.dataset.w) return parseInt(img.dataset.w, 10);
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    var target = window.innerWidth * dpr;
    if (target <= 900)  return 1200;
    if (target <= 1500) return 1600;
    if (target <= 2200) return 2000;
    return 2560;
  }

  // Chaîne de repli : si une photo ne répond pas, on passe à la suivante.
  function guard(img) {
    var queue = (img.dataset.fallback || '').split('|').filter(Boolean);
    var w = widthFor(img);

    img.addEventListener('load', function () {
      img.classList.add('is-loaded');
      document.dispatchEvent(new CustomEvent('photo:loaded', { detail: img }));
    });

    img.addEventListener('error', function () {
      var next = queue.shift();
      if (next) img.src = unsplash(next, w);
    });

    if (img.complete && img.naturalWidth > 0) img.classList.add('is-loaded');
  }

  var photos = Array.prototype.slice.call(document.querySelectorAll('img[data-src], img[src]'));
  photos.forEach(guard);

  // Chargement différé : on charge une photo quand sa section approche.
  var lazy = document.querySelectorAll('img[data-src]');
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries, obs) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        var img = entry.target;
        img.src = unsplash(img.dataset.src, widthFor(img));
        delete img.dataset.src;
        obs.unobserve(img);
      });
    }, { rootMargin: '150% 0px', threshold: 0 });

    Array.prototype.forEach.call(lazy, function (img) { io.observe(img); });
  } else {
    Array.prototype.forEach.call(lazy, function (img) {
      img.src = unsplash(img.dataset.src, widthFor(img));
    });
  }

  /* -------------------------------------------------------
     2. PRELOADER
     ------------------------------------------------------- */

  var preloader = document.getElementById('preloader');
  var preloaderBar = document.getElementById('preloaderBar');
  var heroImg = document.querySelector('.scene--hero .scene__img');
  var started = false;
  var pct = 0;

  var tick = setInterval(function () {
    pct = Math.min(pct + Math.random() * 14, 92);
    if (preloaderBar) preloaderBar.style.width = pct + '%';
  }, 180);

  function launch() {
    if (started) return;
    started = true;
    clearInterval(tick);
    if (preloaderBar) preloaderBar.style.width = '100%';

    setTimeout(function () {
      preloader.classList.add('is-done');
      intro();
    }, 260);
  }

  if (heroImg && heroImg.complete && heroImg.naturalWidth > 0) {
    launch();
  } else if (heroImg) {
    heroImg.addEventListener('load', launch);
    heroImg.addEventListener('error', function () { setTimeout(launch, 900); });
  }
  setTimeout(launch, 4500);              // filet de sécurité
  window.addEventListener('load', function () { setTimeout(launch, 300); });

  /* -------------------------------------------------------
     3. DÉCOUPAGE DES TITRES EN MOTS
     ------------------------------------------------------- */

  function splitTitle(el) {
    if (!el || el.dataset.split) return [];
    el.dataset.split = '1';

    var words = [];
    var nodes = Array.prototype.slice.call(el.childNodes);
    el.innerHTML = '';

    nodes.forEach(function (node) {
      var isEm = node.nodeType === 1;
      var text = (node.textContent || '').trim();
      if (!text) return;

      text.split(/\s+/).forEach(function (w) {
        var mask = document.createElement('span');
        mask.className = 'line-mask';

        var word = document.createElement('span');
        word.className = 'word';
        word.textContent = w;

        if (isEm) {
          var em = document.createElement('em');
          em.appendChild(word);
          mask.appendChild(em);
        } else {
          mask.appendChild(word);
        }
        el.appendChild(mask);
        // Un mot terminé par un trait d'union reste collé au suivant.
        if (!/[-–—']$/.test(w)) el.appendChild(document.createTextNode(' '));
        words.push(word);
      });
    });
    return words;
  }

  /* -------------------------------------------------------
     4. ANIMATION D'OUVERTURE (HERO)
     ------------------------------------------------------- */

  function intro() {
    var heroTitle = document.querySelector('.hero__title');
    var words = splitTitle(heroTitle);
    var bits = document.querySelectorAll('.scene--hero .reveal');

    if (!animate) {
      words.forEach(function (w) { w.style.transform = 'none'; w.style.opacity = 1; });
      Array.prototype.forEach.call(bits, function (b) { b.style.opacity = 1; b.style.transform = 'none'; });
      return;
    }

    var tl = gsap.timeline({ defaults: { ease: 'power3.out' } });

    // Zoom arrière lent de la photo de fond : 1.15 → 1 en 2,5 s
    tl.fromTo(heroImg,
      { scale: 1.15 },
      { scale: 1, duration: 2.5, ease: 'power3.out' }, 0);

    // Titre : fondu + translation verticale, mot par mot
    tl.fromTo(words,
      { yPercent: 115, opacity: 0 },
      { yPercent: 0, opacity: 1, duration: 1.3, stagger: 0.09 }, 0.35);

    // Sur-titre, accroche, boutons, légende
    tl.fromTo(bits,
      { y: 26, opacity: 0 },
      { y: 0, opacity: 1, duration: 1.05, stagger: 0.12 }, 0.85);

    if (hasST) ScrollTrigger.refresh();
  }

  /* -------------------------------------------------------
     5. SCROLLTRIGGER — parallaxe, apparitions, progression
     ------------------------------------------------------- */

  function scrollScenes() {
    if (!animate) return;
    gsap.registerPlugin(ScrollTrigger);

    var scenes = document.querySelectorAll('.scene');

    Array.prototype.forEach.call(scenes, function (scene, i) {
      var media = scene.querySelector('.scene__media');
      var isHero = scene.classList.contains('scene--hero');

      // Parallaxe douce de la photo pendant le défilement
      if (media) {
        gsap.fromTo(media,
          { yPercent: -5 },
          {
            yPercent: 5, ease: 'none',
            scrollTrigger: {
              trigger: scene,
              start: 'top bottom',
              end: 'bottom top',
              scrub: 0.6
            }
          });
      }

      if (isHero) return;

      // Titre de section
      var words = splitTitle(scene.querySelector('.split-title'));
      if (words.length) {
        gsap.fromTo(words,
          { yPercent: 115, opacity: 0 },
          {
            yPercent: 0, opacity: 1, duration: 1.15, stagger: 0.07, ease: 'power3.out',
            scrollTrigger: { trigger: scene, start: 'top 55%', once: true }
          });
      }

      // Textes, listes, formulaire
      var bits = scene.querySelectorAll('.reveal');
      if (bits.length) {
        gsap.fromTo(bits,
          { y: 30, opacity: 0 },
          {
            y: 0, opacity: 1, duration: 1, stagger: 0.11, ease: 'power3.out',
            scrollTrigger: { trigger: scene, start: 'top 50%', once: true }
          });
      }

      // Cartes de chambres
      var cards = scene.querySelectorAll('.card');
      if (cards.length) {
        gsap.fromTo(cards,
          { y: 48, opacity: 0 },
          {
            y: 0, opacity: 1, duration: 1.1, stagger: 0.12, ease: 'power3.out',
            scrollTrigger: { trigger: scene, start: 'top 55%', once: true }
          });
      }
    });

    // Barre de progression
    var bar = document.getElementById('progressBar');
    if (bar) {
      ScrollTrigger.create({
        trigger: document.body,
        start: 'top top',
        end: 'bottom bottom',
        onUpdate: function (self) { bar.style.width = (self.progress * 100).toFixed(2) + '%'; }
      });
    }
  }

  /* -------------------------------------------------------
     6. CARTES 3D — Vanilla-Tilt
     ------------------------------------------------------- */

  function tilt() {
    var cards = document.querySelectorAll('[data-tilt]');
    if (!cards.length) return;

    Array.prototype.forEach.call(cards, function (c) {
      if (c.vanillaTilt) c.vanillaTilt.destroy();
      var glare = c.querySelector('.js-tilt-glare');
      if (glare) glare.parentNode.removeChild(glare);
      c.style.transform = '';
    });

    if (isTouch || reduced || typeof window.VanillaTilt === 'undefined') return;

    VanillaTilt.init(cards, {
      max: 12,
      speed: 600,
      scale: 1.03,
      perspective: 1100,
      glare: true,
      'max-glare': 0.28,
      gyroscope: false
    });
  }

  /* -------------------------------------------------------
     7. NAVIGATION — barre, pastilles, menu mobile
     ------------------------------------------------------- */

  function nav() {
    var topbar = document.getElementById('topbar');
    var dots = document.querySelectorAll('.dots a');
    var scenes = document.querySelectorAll('.scene');

    window.addEventListener('scroll', function () {
      if (topbar) topbar.classList.toggle('is-stuck', window.scrollY > 60);
    }, { passive: true });

    if ('IntersectionObserver' in window) {
      var spy = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var id = entry.target.id;
          Array.prototype.forEach.call(dots, function (d) {
            d.classList.toggle('is-active', d.dataset.target === id);
          });
        });
      }, { threshold: 0.55 });

      Array.prototype.forEach.call(scenes, function (s) { spy.observe(s); });
    }

    var burger = document.getElementById('burger');
    var drawer = document.getElementById('drawer');
    if (burger && drawer) {
      burger.addEventListener('click', function () {
        var open = burger.getAttribute('aria-expanded') === 'true';
        burger.setAttribute('aria-expanded', String(!open));
        drawer.hidden = open;
        document.body.style.overflow = open ? '' : 'hidden';
      });
      drawer.addEventListener('click', function (e) {
        if (e.target.tagName !== 'A') return;
        burger.setAttribute('aria-expanded', 'false');
        drawer.hidden = true;
        document.body.style.overflow = '';
      });
    }
  }

  /* -------------------------------------------------------
     8. FORMULAIRE DE DEMANDE
     ------------------------------------------------------- */

  function form() {
    var f = document.getElementById('bookForm');
    var status = document.getElementById('bookStatus');
    if (!f) return;

    var today = new Date().toISOString().split('T')[0];
    var from = document.getElementById('f-from');
    if (from) { from.min = today; from.value = today; }

    f.addEventListener('submit', function (e) {
      e.preventDefault();

      Array.prototype.forEach.call(f.querySelectorAll('input'), function (i) {
        i.classList.add('is-touched');
      });

      if (!f.checkValidity()) {
        status.textContent = 'Merci de compléter votre nom et votre email.';
        return;
      }

      var name = f.querySelector('#f-name').value.trim().split(/\s+/)[0];
      status.textContent = 'Merci ' + name + ' — notre conciergerie vous répond sous 24 h.';
      f.reset();
      if (from) from.value = today;
    });
  }

  /* -------------------------------------------------------
     9. DÉMARRAGE
     ------------------------------------------------------- */

  function boot() {
    scrollScenes();
    tilt();
    nav();
    form();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }

  // Les photos qui arrivent après coup décalent la page : on recalcule.
  document.addEventListener('photo:loaded', function () {
    if (hasST) ScrollTrigger.refresh();
  });

  var resizeTimer;
  window.addEventListener('resize', function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () {
      if (hasST) ScrollTrigger.refresh();
      tilt();
    }, 220);
  });
})();
