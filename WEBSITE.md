# Moon Hub — Website

Static showcase + store front for **Moon Hub** (Lua hub for Roblox, current version `v1-6`).
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

## 3. Change the look

All colours, radii, fonts and spacing are CSS custom properties at the top of
`css/style.css` (`:root`). Changing `--accent` and `--accent-2` re-themes the
whole site, including the gradient, glows and the mock interface.

## Deploying

Any static host works (GitHub Pages, Netlify, Vercel, Cloudflare Pages).
For GitHub Pages: Settings → Pages → deploy from branch, root folder.
