# Moon Hub — Website

Static showcase + store front for **Moon Hub** (Lua hub for Roblox, current version `v1-6`),
built on the **Black Moon** identity: deep black, moonlight accents, an animated
space background and a short cinematic intro.
No build step, no dependencies: open `index.html` or serve the folder.

```
index.html          Every section (nav, hero, features, versions, key system, pricing, community, footer)
css/style.css       All styling — design tokens live at the top of the file
js/main.js          CONFIG block (links) + nav, reveal animations, counters, scroll spy
assets/             favicon.svg, og-image.svg
```

## 1. Set your links (the only required step)

Open **`js/main.js`** — the `CONFIG` object at the very top is the single place
where every external link lives.

```js
const CONFIG = {
  DISCORD_INVITE: "https://discord.gg/YOUR-INVITE-CODE",
  plans: {
    day:      { url: "https://sellauth.example.com/moon-hub/1-day" },
    week:     { url: "https://sellauth.example.com/moon-hub/1-week" },
    month:    { url: "https://sellauth.example.com/moon-hub/1-month" },
    lifetime: { url: "https://sellauth.example.com/moon-hub/lifetime" }
  },
  openInNewTab: true
};
```

Replace each `url` with the matching **SellAuth** product page. The buttons are
wired by their `data-plan="day|week|month|lifetime"` attribute, and every
"Join Discord" button by `data-link="discord"` — so you never have to hunt for a
button in the HTML.

Any link still pointing at `example.com` (or `YOUR-INVITE-CODE`) is listed as a
warning in the browser console, so nothing is forgotten before going live.

> The site never handles payments. Buttons only redirect to SellAuth, which
> collects the payment and delivers the key automatically.

## 2. Change the prices

Prices are plain HTML, in `index.html`, inside the `#pricing` section:

```html
<p class="price"><span class="price__currency">€</span><span class="price__amount">10</span></p>
<p class="price__period">One-time · 30 days</p>
```

Edit `price__currency`, `price__amount` and `price__period`. To add or remove a
plan, duplicate an `<article class="card card--price">` block and give its button
a new `data-plan` value, then add the matching entry to `CONFIG.plans`.

Badges: `card--featured` + `card__ribbon` ("Most popular") and
`card--lifetime` + `card__ribbon--alt` ("Best value").

## 3. Change the look — the Black Moon theme

Everything visual comes from the CSS custom properties at the top of
`css/style.css` (`:root`): deep blacks, off-white text, light grey secondary
text and a single moonlight accent. Colours exist twice — once as a hex value
and once as raw RGB channels:

```css
--accent:     #a8bef0;
--accent-rgb: 168 190 240;   /* used as rgb(var(--accent-rgb) / .3) */
```

Change those two lines (plus `--accent-2`, `--accent-deep`) and the entire
site re-themes: gradients, glows, the moon, the intro, the scrollbar, the
buttons and the mock interface all follow.

## 4. The intro and the animations

**Intro** (`.intro` in the HTML, section 17 of the CSS, `runIntro()` in the JS):
black screen → spark → moon + loader arc → wordmark → `v1-6` → the moon blooms
into an eclipse that opens the page. Timings live in two constants:

```js
const INTRO_HOLD  = 2650;   // sequence length before the eclipse
const INTRO_LEAVE = 850;    // the eclipse itself (keep in sync with the CSS)
```

It plays **once per browser session**, is skipped on deep links
(`…/#pricing`), can be dismissed with the button, a click or `Esc`, and never
runs at all under `prefers-reduced-motion`. To remove it entirely, delete the
`.intro` block from `index.html` — the page reveals itself either way.

**Scroll reveal**: add `data-reveal` to any element, optionally with a variant
and a position in the stagger:

```html
<div data-reveal="left" data-reveal-delay="2">…</div>
```

Variants: `up` (default), `left`, `right`, `scale`, `blur`, and `text` (the
wrapper stays put and only its lines animate). `data-reveal-delay` is a step
count, 90 ms apart. IntersectionObserver drives it, with a scroll sweep as a
safety net so a fast scroll can never leave an element stuck invisible.

**Parallax**: add `data-parallax="26"` to any element — the number is the pixel
travel, negative to move against the pointer. Fine pointers only; touch devices
and reduced-motion users never run it.

**Performance**: the starfield is painted once into a canvas and drifted by
CSS, so there is no render loop. The only rAF loop is the parallax one, and it
stops as soon as the layers settle. Everything else animates `transform`,
`opacity` and `filter` only.

**Accessibility**: `prefers-reduced-motion: reduce` removes the intro, the
cursor halo and every ambient animation, and shows all content immediately.
An inline safety net in `<head>` reveals the page after 4 s if the script ever
fails to run.

## 5. Deploying

Any static host works (GitHub Pages, Netlify, Vercel, Cloudflare Pages).
For GitHub Pages: Settings → Pages → deploy from branch, root folder.
