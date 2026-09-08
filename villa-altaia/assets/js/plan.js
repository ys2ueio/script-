/* ===========================================================================
   plan.js — le plan architectural se trace au fil du défilement.
   Chaque tracé est converti en pointillé de sa propre longueur ; ScrollTrigger
   réduit le décalage à zéro, ce qui donne l'illusion d'une main qui dessine.
   ========================================================================== */
window.VillaPlan = (function () {
  'use strict';

  var ORDER = ['pl-wall', 'pl-part', 'pl-fix', 'pl-water', 'pl-dim'];

  function measure (el) {
    if (typeof el.getTotalLength !== 'function') return 0;
    try { return el.getTotalLength() || 0; } catch (e) { return 0; }
  }

  return {
    init: function (svg, gsap, ScrollTrigger) {
      if (!svg) return;

      var strokes = [];
      ORDER.forEach(function (cls) {
        Array.prototype.forEach.call(svg.querySelectorAll('.' + cls), function (el) {
          var len = measure(el);
          if (!len) return;
          el.style.strokeDasharray = len;
          el.style.strokeDashoffset = len;
          strokes.push({ el: el, len: len, cls: cls });
        });
      });

      var labels = Array.prototype.slice.call(svg.querySelectorAll('.pl-label, .pl-num'));

      /* Sans GSAP : le plan reste lisible, simplement déjà dessiné. */
      if (!gsap || !ScrollTrigger) {
        strokes.forEach(function (s) { s.el.style.strokeDashoffset = 0; });
        labels.forEach(function (l) { l.style.opacity = 1; });
        return;
      }

      var tl = gsap.timeline({
        scrollTrigger: {
          trigger: svg.closest('section'),
          start: 'top 78%',
          end: 'bottom 62%',
          scrub: 0.8
        }
      });

      /* les groupes s'enchaînent : gros œuvre, refends, agencement, cotes */
      ORDER.forEach(function (cls, gi) {
        var group = strokes.filter(function (s) { return s.cls === cls; });
        if (!group.length) return;
        tl.to(group.map(function (s) { return s.el; }), {
          strokeDashoffset: 0,
          duration: 1.1,
          ease: 'none',
          stagger: 0.055
        }, gi * 0.62);
      });

      tl.to(labels, { opacity: 1, duration: 0.6, stagger: 0.05, ease: 'none' },
            ORDER.length * 0.62 - 0.5);
    }
  };
})();
