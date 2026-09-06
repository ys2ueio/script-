/* ==========================================================================
   MOON HUB — main.js
   ========================================================================== */

/* ==========================================================================
   ▼▼▼  CONFIGURATION — THE ONLY PART YOU NEED TO EDIT  ▼▼▼
   --------------------------------------------------------------------------
   1. Replace DISCORD_INVITE with your real Discord invite link.
   2. Replace every `url` below with the matching SellAuth product link.
      Example: "https://your-store.mysellauth.com/product/moon-hub-1-month"
   3. Prices are displayed in index.html (section #pricing) — edit them there.

   Anything still pointing at "example.com" is logged as a warning in the
   browser console so you can spot forgotten links immediately.
   ========================================================================== */
const CONFIG = {
  /* Discord invite used by every "Join Discord" button on the site */
  DISCORD_INVITE: "https://discord.gg/YOUR-INVITE-CODE",

  /* SellAuth checkout links, one per plan.
     The `id` matches the data-plan="…" attribute on the buy buttons. */
  plans: {
    day:      { url: "https://sellauth.example.com/moon-hub/1-day" },
    week:     { url: "https://sellauth.example.com/moon-hub/1-week" },
    month:    { url: "https://sellauth.example.com/moon-hub/1-month" },
    lifetime: { url: "https://sellauth.example.com/moon-hub/lifetime" }
  },

  /* Open store / Discord links in a new tab */
  openInNewTab: true
};
/* ==========================================================================
   ▲▲▲  END OF CONFIGURATION  ▲▲▲
   ========================================================================== */




(function () {
  "use strict";

  const $  = (sel, ctx = document) => ctx.querySelector(sel);
  const $$ = (sel, ctx = document) => Array.from(ctx.querySelectorAll(sel));

  const reduceMotion   = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const finePointer    = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  const canObserve     = "IntersectionObserver" in window;

  /* ==================================================================
     External links — Discord + SellAuth (see CONFIG at the top)
     ================================================================== */
  function applyLink(el, url) {
    if (!url) return;
    el.href = url;
    if (CONFIG.openInNewTab) {
      el.target = "_blank";
      el.rel = "noopener noreferrer";
    }
  }

  function hydrateLinks() {
    const unconfigured = [];

    $$("[data-link='discord']").forEach((el) => applyLink(el, CONFIG.DISCORD_INVITE));
    if (/YOUR-INVITE-CODE/i.test(CONFIG.DISCORD_INVITE)) unconfigured.push("DISCORD_INVITE");

    $$("[data-plan]").forEach((el) => {
      const plan = CONFIG.plans[el.dataset.plan];
      if (!plan) {
        console.warn(`[Moon Hub] Unknown plan "${el.dataset.plan}" on`, el);
        return;
      }
      applyLink(el, plan.url);
      if (/example\.com/i.test(plan.url) && !unconfigured.includes(`plans.${el.dataset.plan}`)) {
        unconfigured.push(`plans.${el.dataset.plan}`);
      }
    });

    if (unconfigured.length) {
      console.warn(
        "[Moon Hub] These links are still placeholders — edit CONFIG in js/main.js:\n  • " +
          unconfigured.join("\n  • ")
      );
    }
  }

  /* ==================================================================
     INTRO — black → spark → moon → wordmark → eclipse → page
     ------------------------------------------------------------------
     Plays once per browser session. Skipped outright under reduced
     motion, or when the visitor arrives on a deep link (#pricing…).
     `done` is called when the page underneath should start animating,
     which is while the eclipse is still opening — the two overlap.
     ================================================================== */
  const INTRO_HOLD  = 2650;   // ms of sequence before the eclipse opens
  const INTRO_LEAVE = 850;    // ms of the eclipse itself (matches the CSS)

  function runIntro(done) {
    const intro = $("#intro");
    if (!intro) return done();

    const seen    = sessionStorage.getItem("mh-intro-seen") === "1";
    const deepLink = window.location.hash && window.location.hash !== "#home";

    if (reduceMotion || seen || deepLink) {
      intro.remove();
      return done();
    }

    let finished = false;
    document.body.classList.add("intro-active");

    const finish = () => {
      if (finished) return;
      finished = true;
      try { sessionStorage.setItem("mh-intro-seen", "1"); } catch (_) { /* private mode */ }
      window.clearTimeout(timer);
      intro.classList.add("is-leaving");
      document.body.classList.remove("intro-active");
      document.removeEventListener("keydown", onKey);
      done();                                   // page starts revealing behind
      window.setTimeout(() => intro.remove(), INTRO_LEAVE);
    };

    const onKey = (e) => { if (e.key === "Escape" || e.key === "Enter" || e.key === " ") finish(); };

    const timer = window.setTimeout(finish, INTRO_HOLD);
    $("#intro-skip")?.addEventListener("click", finish);
    intro.addEventListener("click", finish);
    document.addEventListener("keydown", onKey);
  }

  /* ==================================================================
     STARFIELD — painted once into a canvas, then drifted by CSS.
     No render loop, so it costs nothing after the first paint.
     ================================================================== */
  function initStarfield() {
    const canvas = $("#starfield");
    if (!canvas) return;
    const ctx = canvas.getContext("2d", { alpha: true });
    if (!ctx) return;

    const TIERS = [
      { r: 0.6, alpha: 0.30, share: 0.60 },   // distant dust
      { r: 1.0, alpha: 0.55, share: 0.30 },   // mid field
      { r: 1.5, alpha: 0.85, share: 0.10 }    // the few bright ones
    ];

    let lastKey = "";

    const paint = () => {
      const w = canvas.offsetWidth;
      const h = canvas.offsetHeight;
      if (!w || !h) return;

      const key = `${w}x${h}`;
      if (key === lastKey) return;              // ignore mobile URL-bar resizes
      lastKey = key;

      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width  = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);

      const density = finePointer ? 9000 : 16000;   // fewer stars on phones
      const total   = Math.min(Math.round((w * h) / density), 220);

      TIERS.forEach((tier) => {
        ctx.fillStyle = `rgba(233, 239, 253, ${tier.alpha})`;
        const count = Math.round(total * tier.share);
        for (let i = 0; i < count; i++) {
          ctx.beginPath();
          ctx.arc(Math.random() * w, Math.random() * h, tier.r, 0, Math.PI * 2);
          ctx.fill();
        }
      });
    };

    paint();

    let resizeTimer;
    window.addEventListener("resize", () => {
      window.clearTimeout(resizeTimer);
      resizeTimer = window.setTimeout(paint, 220);
    }, { passive: true });
  }

  /* ==================================================================
     PARALLAX + CURSOR HALO
     ------------------------------------------------------------------
     One rAF loop, started by pointer movement and stopped as soon as
     the layers have settled. Fine pointers only — never on touch.
     ================================================================== */
  function initPointerEffects() {
    if (reduceMotion || !finePointer) return;

    const layers = $$("[data-parallax]").map((el) => ({
      el,
      depth: parseFloat(el.dataset.parallax) || 0
    }));
    const glow = $("#cursor-glow");
    if (!layers.length && !glow) return;

    let targetX = 0, targetY = 0;          // -0.5 … 0.5, relative to viewport
    let curX = 0, curY = 0;
    let glowX = window.innerWidth / 2, glowY = window.innerHeight / 2;
    let pointerX = glowX, pointerY = glowY;
    let running = false;

    const frame = () => {
      curX  += (targetX - curX) * 0.06;
      curY  += (targetY - curY) * 0.06;
      glowX += (pointerX - glowX) * 0.12;
      glowY += (pointerY - glowY) * 0.12;

      layers.forEach(({ el, depth }) => {
        el.style.transform =
          `translate3d(${(curX * depth).toFixed(2)}px, ${(curY * depth).toFixed(2)}px, 0)`;
      });
      if (glow) glow.style.transform = `translate3d(${glowX.toFixed(1)}px, ${glowY.toFixed(1)}px, 0)`;

      const settled =
        Math.abs(targetX - curX) < 0.0005 &&
        Math.abs(targetY - curY) < 0.0005 &&
        Math.abs(pointerX - glowX) < 0.5 &&
        Math.abs(pointerY - glowY) < 0.5;

      if (settled) { running = false; return; }
      requestAnimationFrame(frame);
    };

    const start = () => {
      if (running) return;
      running = true;
      requestAnimationFrame(frame);
    };

    window.addEventListener("pointermove", (e) => {
      if (e.pointerType !== "mouse") return;
      pointerX = e.clientX;
      pointerY = e.clientY;
      targetX = (e.clientX / window.innerWidth) - 0.5;
      targetY = (e.clientY / window.innerHeight) - 0.5;
      glow?.classList.add("is-live");
      start();
    }, { passive: true });

    document.addEventListener("pointerleave", () => glow?.classList.remove("is-live"));
  }

  /* ==================================================================
     NAVIGATION
     ================================================================== */
  function initNav() {
    const nav    = $("#nav");
    const toggle = $("#nav-toggle");
    const menu   = $("#nav-menu");
    if (!nav || !toggle || !menu) return;

    const setOpen = (open) => {
      toggle.setAttribute("aria-expanded", String(open));
      toggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
      menu.classList.toggle("is-open", open);
      document.body.classList.toggle("nav-open", open);
    };

    toggle.addEventListener("click", () => {
      setOpen(toggle.getAttribute("aria-expanded") !== "true");
    });

    $$("a", menu).forEach((link) => link.addEventListener("click", () => setOpen(false)));

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && toggle.getAttribute("aria-expanded") === "true") {
        setOpen(false);
        toggle.focus();
      }
    });

    window.matchMedia("(min-width: 861px)").addEventListener("change", (e) => {
      if (e.matches) setOpen(false);
    });

    const onScroll = () => nav.classList.toggle("is-stuck", window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* ==================================================================
     SECTION TRANSITIONS — a light sweep over the section you jump to
     ================================================================== */
  function initSectionTransitions() {
    if (reduceMotion) return;

    document.addEventListener("click", (e) => {
      const link = e.target.closest('a[href^="#"]');
      if (!link) return;
      const id = link.getAttribute("href");
      if (!id || id === "#" || id === "#main") return;

      const target = document.querySelector(id);
      if (!target || !target.matches("section")) return;

      target.classList.remove("is-entering");
      void target.offsetWidth;                 // restart the animation
      target.classList.add("is-entering");
      window.setTimeout(() => target.classList.remove("is-entering"), 950);
    });
  }

  /* ==================================================================
     SCROLL REVEAL — fade-up / left / right / scale / blur
     ================================================================== */
  function initReveal() {
    const items = $$("[data-reveal]");
    const title = $(".hero__title");

    items.forEach((el) => {
      if (el.dataset.revealDelay) el.style.setProperty("--reveal-delay", el.dataset.revealDelay);
    });

    if (reduceMotion || !canObserve) {
      items.forEach((el) => el.classList.add("is-visible"));
      title?.classList.add("is-visible");
      return;
    }

    /* Elements still waiting to be revealed. IntersectionObserver drives the
       normal case; the sweep below catches anything a fast scroll (or a jump
       to an anchor) flew past without the observer ever reporting it. */
    const pending = new Set(items);

    const reveal = (el) => {
      el.classList.add("is-visible");
      pending.delete(el);
      observer.unobserve(el);
    };

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) reveal(entry.target);
        });
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0 }
    );

    items.forEach((el) => observer.observe(el));

    let ticking = false;
    const sweep = () => {
      ticking = false;
      const limit = window.innerHeight * 0.92;
      pending.forEach((el) => {
        if (el.getBoundingClientRect().top < limit) reveal(el);
      });
      if (!pending.size) {
        window.removeEventListener("scroll", onScroll);
        window.removeEventListener("resize", onScroll);
      }
    };
    const onScroll = () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(sweep);
    };

    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll, { passive: true });
    onScroll();
  }

  /* ==================================================================
     STATS — 0 → 3 250+, eased, once
     ================================================================== */
  function initCounters() {
    const counters = $$("[data-count]");
    if (!counters.length || reduceMotion || !canObserve) return;

    const run = (el) => {
      const target = Number(el.dataset.count);
      if (!Number.isFinite(target)) return;
      const duration = 1600;
      const start = performance.now();

      const tick = (now) => {
        const p = Math.min((now - start) / duration, 1);
        const eased = 1 - Math.pow(1 - p, 3);
        el.textContent = Math.round(target * eased).toLocaleString("en-US");
        if (p < 1) requestAnimationFrame(tick);
      };
      el.textContent = "0";
      requestAnimationFrame(tick);
    };

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          run(entry.target);
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.6 }
    );

    counters.forEach((el) => observer.observe(el));
  }

  /* ==================================================================
     Nav link matching the section in view
     ================================================================== */
  function initScrollSpy() {
    const links = $$(".nav__link");
    if (!links.length || !canObserve) return;

    const map = new Map();
    links.forEach((link) => {
      const id = link.getAttribute("href");
      const section = id && id.startsWith("#") ? $(id) : null;
      if (section) map.set(section, link);
    });
    if (!map.size) return;

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          links.forEach((l) => l.classList.remove("is-active"));
          map.get(entry.target)?.classList.add("is-active");
        });
      },
      { rootMargin: "-45% 0px -50% 0px", threshold: 0 }
    );

    map.forEach((_, section) => observer.observe(section));
  }

  function initYear() {
    const year = $("#year");
    if (year) year.textContent = String(new Date().getFullYear());
  }

  /* ==================================================================
     Boot
     ================================================================== */
  function revealPage() {
    $("#nav")?.classList.add("is-ready");
    $(".page-shell")?.classList.add("is-ready");
    initReveal();
    initCounters();
  }

  function init() {
    try {
      hydrateLinks();
      initNav();
      initYear();
      initStarfield();
      initPointerEffects();
      initScrollSpy();
      initSectionTransitions();
      runIntro(revealPage);
    } catch (err) {
      /* Whatever breaks, the content must still be readable */
      console.error("[Moon Hub]", err);
      $("#intro")?.remove();
      document.body.classList.remove("intro-active");
      revealPage();
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
