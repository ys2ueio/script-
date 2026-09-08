/* ===========================================================================
   lazy.js — chargement différé des visuels haute définition.
   IntersectionObserver déclenche le chargement 400 px avant l'entrée dans le
   cadre : l'image est déjà décodée quand le chapitre arrive à l'écran.
   ========================================================================== */
(function () {
  'use strict';

  var SELECTOR = 'img[data-src], img[data-srcset], video[data-src]';
  var MARGIN = '400px 0px';

  function reveal (el) {
    el.classList.add('is-loaded');
    var holder = el.closest('.holder');
    if (holder) holder.classList.add('is-loaded');
    el.dispatchEvent(new CustomEvent('villa:loaded', { bubbles: true }));
  }

  function load (el) {
    if (el.dataset.loading) return;
    el.dataset.loading = '1';

    if (el.dataset.srcset) el.srcset = el.dataset.srcset;
    if (el.dataset.sizes) el.sizes = el.dataset.sizes;

    var src = el.dataset.src;
    if (!src) { reveal(el); return; }

    /* on précharge hors document : pas de reflow tant que l'image n'est pas prête */
    if (el.tagName === 'IMG') {
      var probe = new Image();
      probe.decoding = 'async';
      probe.onload = function () {
        el.src = src;
        var done = function () { reveal(el); };
        if (el.decode) el.decode().then(done, done); else done();
      };
      probe.onerror = function () {
        el.src = src;         /* laisse le navigateur afficher son propre échec */
        reveal(el);
      };
      probe.src = src;
    } else {
      el.src = src;
      el.addEventListener('loadeddata', function () { reveal(el); }, { once: true });
    }

    delete el.dataset.src;
    delete el.dataset.srcset;
  }

  function start () {
    var targets = Array.prototype.slice.call(document.querySelectorAll(SELECTOR));
    if (!targets.length) return;

    if (!('IntersectionObserver' in window)) {   /* repli : tout charger */
      targets.forEach(load);
      return;
    }

    var io = new IntersectionObserver(function (entries, obs) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        obs.unobserve(entry.target);
        load(entry.target);
      });
    }, { rootMargin: MARGIN, threshold: 0.01 });

    targets.forEach(function (el) { io.observe(el); });

    /* Filet de sécurité : un saut d'ancre traverse des sections sans qu'aucune
       intersection ne soit signalée. On balaie donc aussi ce qui est déjà passé
       au-dessus du cadre — l'observateur seul laisserait des vides. */
    var sweeping = 0;
    function sweep () {
      sweeping = 0;
      targets.forEach(function (el) {
        if (!el.dataset.src) return;
        if (el.getBoundingClientRect().top < window.innerHeight * 1.4) {
          io.unobserve(el);
          load(el);
        }
      });
    }
    function sweepSoon () {
      if (sweeping) return;
      sweeping = setTimeout(sweep, 200);
    }
    window.addEventListener('load', sweepSoon);
    window.addEventListener('scroll', sweepSoon, { passive: true });
    window.addEventListener('resize', sweepSoon, { passive: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else { start(); }

  window.VillaLazy = { load: load };
})();
