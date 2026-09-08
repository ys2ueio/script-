/* ===========================================================================
   main.js — chef d'orchestre.
   Relie le défilement (GSAP + ScrollTrigger) au travelling WebGL, aux calques
   de parallaxe, aux entrées de texte, aux cartes Vanilla Tilt et au rail.
   Tout est facultatif : si une bibliothèque manque, la page reste lisible.
   ========================================================================== */
(function () {
  'use strict';

  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var gsap = window.gsap;
  var ST = window.ScrollTrigger;
  var hasGsap = !!(gsap && ST) && !reduce;

  if (hasGsap) {
    gsap.registerPlugin(ST);
    /* ScrollTrigger recalcule ses bornes en remettant brièvement le scroll à
       zéro ; l'aimantation CSS s'y oppose et fausse toutes les mesures. On la
       suspend le temps du recalcul — c'est la seule façon de faire cohabiter
       scroll-snap natif et timelines scrubbées. */
    var snapRoot = document.documentElement;
    ST.addEventListener('refreshInit', function () {
      snapRoot.style.scrollSnapType = 'none';
    });
    ST.addEventListener('refresh', function () {
      snapRoot.style.scrollSnapType = '';
    });
  }

  var doc = document;
  var sections = Array.prototype.slice.call(doc.querySelectorAll('.chapter'));

  /* --- 0. ancres adoucies ----------------------------------------------- */
  doc.addEventListener('click', function (e) {
    var a = e.target.closest ? e.target.closest('a[href^="#"]') : null;
    if (!a) return;
    var id = a.getAttribute('href').slice(1);
    var target = id && doc.getElementById(id);
    if (!target) return;
    e.preventDefault();
    var top = window.scrollY + target.getBoundingClientRect().top;
    try {
      window.scrollTo({ top: top, behavior: reduce ? 'auto' : 'smooth' });
    } catch (err) { window.scrollTo(0, top); }
    if (history.replaceState) history.replaceState(null, '', '#' + id);
  });

  /* --- 1. sans animation : on rend tout visible et on s'arrête ---------- */
  if (!hasGsap) {
    Array.prototype.forEach.call(doc.querySelectorAll('.reveal-item'), function (el) {
      el.style.opacity = 1; el.style.transform = 'none';
    });
    window.VillaPlan.init(doc.getElementById('plan-svg'), null, null);
    railWithoutGsap();
    if (reduce) pauseHeroVideo();
    return;
  }

  /* --- 2. travelling WebGL piloté par la progression globale ------------ */
  var scene = window.VillaScene;
  var glReady = scene.init(doc.getElementById('gl'));

  ST.create({
    trigger: '.chapters',
    start: 'top top',
    end: 'bottom bottom',
    onUpdate: function (self) { if (glReady) scene.setProgress(self.progress); }
  });

  /* --- 3. parallaxe du hero : un calque, une vitesse -------------------- */
  var hero = doc.getElementById('sommets');
  if (hero) {
    var layers = Array.prototype.slice.call(hero.querySelectorAll('.layer'));
    var tlHero = gsap.timeline({
      scrollTrigger: { trigger: hero, start: 'top top', end: 'bottom top', scrub: 0.6 }
    });
    layers.forEach(function (el) {
      var d = parseFloat(el.dataset.depth || '0.2');
      tlHero.to(el, {
        yPercent: -34 * d * 3.2,     /* les avant-plans filent, le ciel reste */
        scale: 1 + d * 0.24,
        ease: 'none'
      }, 0);
    });
    /* le texte du hero s'efface pendant que la caméra plonge */
    tlHero.to(hero.querySelector('.wrap'), { yPercent: -18, opacity: 0, ease: 'none' }, 0);
    tlHero.to(hero.querySelector('.scroll-hint'), { opacity: 0, ease: 'none' }, 0);
  }

  /* --- 4. cadrage photographique : zoom lent lié au scroll -------------- */
  Array.prototype.forEach.call(doc.querySelectorAll('[data-scrub]'), function (img) {
    /* l'échelle reste toujours > 1 : la translation ne doit jamais découvrir
       le bord du cadre */
    var to = Math.max(1.1, parseFloat(img.dataset.scrub) || 1.1);
    gsap.fromTo(img,
      { scale: to + 0.06, yPercent: 4 },
      {
        scale: to, yPercent: -4, ease: 'none',
        scrollTrigger: {
          trigger: img.closest('.chapter'),
          start: 'top bottom', end: 'bottom top', scrub: true
        }
      });
  });

  /* --- 5. entrées de texte, chapitre par chapitre ----------------------- */
  Array.prototype.forEach.call(doc.querySelectorAll('.reveal'), function (block) {
    var items = block.querySelectorAll('.reveal-item');
    if (!items.length) return;
    gsap.to(items, {
      opacity: 1, y: 0, duration: 1.05, ease: 'power3.out', stagger: 0.09,
      scrollTrigger: { trigger: block, start: 'top 82%', once: true }
    });
  });
  /* les éléments isolés (hors bloc .reveal) */
  Array.prototype.forEach.call(doc.querySelectorAll('.reveal-item'), function (el) {
    if (el.closest('.reveal')) return;
    gsap.to(el, {
      opacity: 1, y: 0, duration: 1.05, ease: 'power3.out',
      scrollTrigger: { trigger: el, start: 'top 88%', once: true }
    });
  });

  /* --- 6. plan architectural -------------------------------------------- */
  window.VillaPlan.init(doc.getElementById('plan-svg'), gsap, ST);

  /* --- 7. cartes : léger basculement 3D au survol (sans WebGL) ---------- */
  if (window.VanillaTilt && window.matchMedia('(hover: hover) and (pointer: fine)').matches) {
    var cards = doc.querySelectorAll('[data-tilt]');
    window.VanillaTilt.init(cards, {
      max: 7, speed: 500, glare: false, scale: 1.015,
      perspective: 1200, transition: true, gyroscope: false, reset: true
    });
    /* reflet suivant le curseur, cohérent avec l'inclinaison */
    Array.prototype.forEach.call(cards, function (card) {
      card.addEventListener('pointermove', function (e) {
        var r = card.getBoundingClientRect();
        card.style.setProperty('--mx', ((e.clientX - r.left) / r.width * 100) + '%');
        card.style.setProperty('--my', ((e.clientY - r.top) / r.height * 100) + '%');
      });
    });
  }

  /* --- 8. rail et navigation : chapitre courant ------------------------- */
  var railLinks = Array.prototype.slice.call(doc.querySelectorAll('[data-rail]'));
  var navLinks = Array.prototype.slice.call(doc.querySelectorAll('.masthead nav a'));

  function mark (id) {
    railLinks.concat(navLinks).forEach(function (a) {
      var on = a.getAttribute('href') === '#' + id;
      if (on) a.setAttribute('aria-current', 'true');
      else a.removeAttribute('aria-current');
    });
  }
  /* Le chapitre courant est celui dont le centre est le plus proche du centre
     de la fenêtre : robuste aux sauts d'ancre comme au défilement continu. */
  var current = '';
  function syncCurrent () {
    var mid = window.innerHeight / 2, best = null, bestD = Infinity;
    sections.forEach(function (sec) {
      var r = sec.getBoundingClientRect();
      var d = Math.abs((r.top + r.bottom) / 2 - mid);
      if (d < bestD) { bestD = d; best = sec; }
    });
    if (best && best.id !== current) { current = best.id; mark(current); }
  }
  ST.create({ trigger: '.chapters', start: 'top top', end: 'bottom bottom',
              onUpdate: syncCurrent, onRefresh: syncCurrent });
  window.addEventListener('resize', syncCurrent, { passive: true });
  syncCurrent();

  /* --- 9. vidéo du hero : on ne la joue que lorsqu'elle est visible ----- */
  var video = doc.getElementById('hero-video');
  if (video) {
    if (reduce) { pauseHeroVideo(); }
    else if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        entries.forEach(function (en) {
          if (en.isIntersecting) { var p = video.play(); if (p) p.catch(function () {}); }
          else video.pause();
        });
      }, { threshold: 0.05 }).observe(video);
    }
    /* si la lecture automatique est refusée, l'affiche reste : rien ne casse */
    video.addEventListener('error', function () { video.style.display = 'none'; }, true);
  }

  /* --- 10. le chargement différé peut décaler la page ------------------- */
  var refreshTimer = 0;
  function refreshSoon () {
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(function () { ST.refresh(); }, 160);
  }
  doc.addEventListener('villa:loaded', refreshSoon);
  window.addEventListener('load', refreshSoon);

  /* --- utilitaires ------------------------------------------------------ */
  function pauseHeroVideo () {
    var v = doc.getElementById('hero-video');
    if (!v) return;
    v.pause(); v.removeAttribute('autoplay'); v.currentTime = 0;
  }

  function railWithoutGsap () {
    if (!('IntersectionObserver' in window)) return;
    var links = Array.prototype.slice.call(
      doc.querySelectorAll('[data-rail], .masthead nav a'));
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        links.forEach(function (a) {
          if (a.getAttribute('href') === '#' + en.target.id) {
            a.setAttribute('aria-current', 'true');
          } else {
            a.removeAttribute('aria-current');
          }
        });
      });
    }, { threshold: 0.5 });
    sections.forEach(function (sec) { io.observe(sec); });
  }
})();
