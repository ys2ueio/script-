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

  const prefersReducedMotion =
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ------------------------------------------------------------------
     External links — Discord + SellAuth
     ------------------------------------------------------------------ */
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

    $$("[data-link='discord']").forEach((el) => {
      applyLink(el, CONFIG.DISCORD_INVITE);
    });
    if (/YOUR-INVITE-CODE/i.test(CONFIG.DISCORD_INVITE)) {
      unconfigured.push("DISCORD_INVITE");
    }

    $$("[data-plan]").forEach((el) => {
      const plan = CONFIG.plans[el.dataset.plan];
      if (!plan) {
        console.warn(`[Moon Hub] Unknown plan "${el.dataset.plan}" on`, el);
        return;
      }
      applyLink(el, plan.url);
      if (/example\.com/i.test(plan.url) && !unconfigured.includes(el.dataset.plan)) {
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

  /* ------------------------------------------------------------------
     Mobile navigation
     ------------------------------------------------------------------ */
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

    /* Close after picking a destination */
    $$("a", menu).forEach((link) =>
      link.addEventListener("click", () => setOpen(false))
    );

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && toggle.getAttribute("aria-expanded") === "true") {
        setOpen(false);
        toggle.focus();
      }
    });

    /* Reset when resizing back to desktop */
    window.matchMedia("(min-width: 861px)").addEventListener("change", (e) => {
      if (e.matches) setOpen(false);
    });

    /* Solid background once scrolled */
    const onScroll = () => nav.classList.toggle("is-stuck", window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* ------------------------------------------------------------------
     Scroll reveal
     ------------------------------------------------------------------ */
  function initReveal() {
    const items = $$("[data-reveal]");
    if (!items.length) return;

    items.forEach((el) => {
      if (el.dataset.revealDelay) {
        el.style.setProperty("--reveal-delay", el.dataset.revealDelay);
      }
    });

    if (prefersReducedMotion || !("IntersectionObserver" in window)) {
      items.forEach((el) => el.classList.add("is-visible"));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.12 }
    );

    items.forEach((el) => observer.observe(el));
  }

  /* ------------------------------------------------------------------
     Animated counters
     ------------------------------------------------------------------ */
  function initCounters() {
    const counters = $$("[data-count]");
    if (!counters.length) return;

    if (prefersReducedMotion || !("IntersectionObserver" in window)) return;

    const run = (el) => {
      const target = Number(el.dataset.count);
      if (!Number.isFinite(target)) return;
      const duration = 1400;
      const start = performance.now();

      const tick = (now) => {
        const p = Math.min((now - start) / duration, 1);
        const eased = 1 - Math.pow(1 - p, 3);
        el.textContent = Math.round(target * eased).toLocaleString("en-US");
        if (p < 1) requestAnimationFrame(tick);
      };
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

  /* ------------------------------------------------------------------
     Highlight the nav link of the section in view
     ------------------------------------------------------------------ */
  function initScrollSpy() {
    const links = $$(".nav__link");
    if (!links.length || !("IntersectionObserver" in window)) return;

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

  /* ------------------------------------------------------------------
     Footer year
     ------------------------------------------------------------------ */
  function initYear() {
    const year = $("#year");
    if (year) year.textContent = String(new Date().getFullYear());
  }

  /* ------------------------------------------------------------------
     Boot
     ------------------------------------------------------------------ */
  function init() {
    hydrateLinks();
    initNav();
    initReveal();
    initCounters();
    initScrollSpy();
    initYear();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
