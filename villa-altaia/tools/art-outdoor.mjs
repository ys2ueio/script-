/* ---------------------------------------------------------------------------
 * art-outdoor.mjs — scènes extérieures : ciel, crêtes, forêt, chalet.
 * Chaque calque est transparent afin d'être empilé (parallaxe de profondeur).
 * ------------------------------------------------------------------------- */
import {
  PAL, rng, n, fractal, envelope, ridgePath, snowPath, firLine,
  defsCommon, grainOverlay, svg
} from './art-lib.mjs';

const W = 1920, H = 1080;

/* — 1. ciel : dégradé froid, halo solaire bas, nuages étirés -------------- */
export function sky () {
  const rnd = rng(1041);
  let clouds = '';
  for (let i = 0; i < 9; i++) {
    const y = 120 + rnd() * 420;
    const w = 260 + rnd() * 760;
    const h = 12 + rnd() * 30;
    clouds += `<ellipse cx="${n(rnd() * W)}" cy="${n(y)}" rx="${n(w)}" ry="${n(h)}" ` +
              `fill="url(#cl)" opacity="${n(0.10 + rnd() * 0.16, 3)}"/>`;
  }
  return svg(W, H, `
  <defs>
    ${defsCommon()}
    <linearGradient id="sk" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%"   stop-color="#0b0e11"/>
      <stop offset="34%"  stop-color="#1a2027"/>
      <stop offset="66%"  stop-color="#3a3f45"/>
      <stop offset="86%"  stop-color="#6d6a63"/>
      <stop offset="100%" stop-color="${PAL.sand}"/>
    </linearGradient>
    <radialGradient id="sun" cx="72%" cy="82%" r="46%">
      <stop offset="0%"   stop-color="${PAL.emberL}" stop-opacity="0.85"/>
      <stop offset="38%"  stop-color="${PAL.ember}"  stop-opacity="0.30"/>
      <stop offset="100%" stop-color="${PAL.ember}"  stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="cl" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%"   stop-color="${PAL.haze}" stop-opacity="0"/>
      <stop offset="50%"  stop-color="${PAL.cream}" stop-opacity="1"/>
      <stop offset="100%" stop-color="${PAL.haze}" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#sk)"/>
  <g filter="url(#haze)">${clouds}</g>
  <rect width="${W}" height="${H}" fill="url(#sun)"/>
  ${grainOverlay(W, H, 0.05)}`);
}

/* — fabrique de crêtes réutilisable --------------------------------------- */
function range ({ seed, baseY, amp, peaks, levels = 7, rough = 0.54 }) {
  const rnd = rng(seed);
  const raw = fractal(rnd, levels, rough);
  const env = envelope(raw.length, peaks);
  const heights = raw.map((v, i) => Math.min(1, (0.34 + v * 0.66) * env[i]));
  const path = ridgePath(heights, { w: W, baseY, amp });
  return { rnd, path };
}

/* — 2. sommets lointains : très voilés, neige dominante ------------------- */
export function peaksFar () {
  const { rnd, path } = range({
    seed: 22, baseY: 690, amp: 430,
    peaks: [{ x: 0.14, h: 0.86, w: 0.13 }, { x: 0.41, h: 1.0, w: 0.11 },
            { x: 0.63, h: 0.74, w: 0.15 }, { x: 0.88, h: 0.93, w: 0.12 }]
  });
  return svg(W, H, `
  <defs>
    ${defsCommon('F')}
    <linearGradient id="rf" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#8e959c"/><stop offset="100%" stop-color="#4a5158"/>
    </linearGradient>
    <linearGradient id="sf" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="${PAL.snow}"/><stop offset="100%" stop-color="#c9cdd1" stop-opacity="0.15"/>
    </linearGradient>
    <clipPath id="cf"><path d="${path.closed}"/></clipPath>
  </defs>
  <g opacity="0.72">
    <path d="${path.closed}" fill="url(#rf)"/>
    <g clip-path="url(#cf)"><path d="${snowPath(path.pts, 118, rnd, W, 690)}" fill="url(#sf)"/></g>
  </g>
  <rect width="${W}" height="${H}" fill="#3a3f45" opacity="0.26" style="mix-blend-mode:screen"/>`);
}

/* — 3. crêtes intermédiaires : contraste et arêtes marquées --------------- */
export function peaksMid () {
  const { rnd, path } = range({
    seed: 907, baseY: 830, amp: 470, rough: 0.5,
    peaks: [{ x: 0.06, h: 0.72, w: 0.16 }, { x: 0.30, h: 0.98, w: 0.12 },
            { x: 0.55, h: 0.83, w: 0.14 }, { x: 0.79, h: 1.0, w: 0.10 }]
  });
  /* couloirs d'ombre : quelques traits descendant des sommets */
  let gullies = '';
  for (let i = 0; i < 26; i++) {
    const idx = Math.floor(rnd() * path.pts.length);
    const [x, y] = path.pts[idx];
    gullies += `<path d="M ${x} ${y} L ${n(x + (rnd() - 0.5) * 70)} ${n(y + 120 + rnd() * 260)}" ` +
               `stroke="#141719" stroke-width="${n(2 + rnd() * 9, 1)}" opacity="${n(0.18 + rnd() * 0.22, 3)}" fill="none"/>`;
  }
  return svg(W, H, `
  <defs>
    ${defsCommon('M')}
    <linearGradient id="rm" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#5d656d"/><stop offset="62%" stop-color="#333940"/>
      <stop offset="100%" stop-color="#21262b"/>
    </linearGradient>
    <linearGradient id="sm" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="${PAL.snow}"/><stop offset="100%" stop-color="#aeb4ba" stop-opacity="0.1"/>
    </linearGradient>
    <clipPath id="cm"><path d="${path.closed}"/></clipPath>
  </defs>
  <path d="${path.closed}" fill="url(#rm)"/>
  <g clip-path="url(#cm)">
    <path d="${snowPath(path.pts, 96, rnd, W, 830)}" fill="url(#sm)" opacity="0.94"/>
    ${gullies}
  </g>
  ${grainOverlay(W, H, 0.06, 'M')}`);
}

/* — 4. forêt : deux rideaux de sapins sur un talus enneigé ---------------- */
export function forest () {
  const rnd = rng(5150);
  const slope = `M 0 900 C 380 848 760 884 1120 856 C 1440 832 1700 866 1920 842 L 1920 1080 L 0 1080 Z`;
  return svg(W, H, `
  <defs>
    ${defsCommon('T')}
    <linearGradient id="sl" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#dcd6cd"/><stop offset="40%" stop-color="#9ba0a6"/>
      <stop offset="100%" stop-color="#2b3037"/>
    </linearGradient>
  </defs>
  <g opacity="0.55"><path d="${firLine(rnd, { w: W, groundY: 902, count: 58, hMin: 96, hMax: 178, jitterY: 16 })}" fill="#242a30"/></g>
  <path d="${slope}" fill="url(#sl)"/>
  <path d="${firLine(rnd, { w: W, groundY: 972, count: 34, hMin: 150, hMax: 300, jitterY: 26 })}" fill="#14181c"/>
  ${grainOverlay(W, H, 0.05, 'T')}`);
}

/* — 5. chalet : volume principal, toit enneigé, fenêtres incandescentes --- */
export function chalet () {
  const rnd = rng(77);

  /* bardage : lames verticales, densité irrégulière */
  let planks = '';
  for (let x = 646; x < 1280; x += 11 + Math.floor(rnd() * 7)) {
    planks += `<path d="M ${x} 722 L ${x} 966" stroke="#0a0c0d" stroke-width="1.6" ` +
              `opacity="${n(0.18 + rnd() * 0.28, 3)}"/>`;
  }
  /* moellons du soubassement */
  let stones = '';
  for (let r = 0; r < 3; r++) {
    for (let x = 620; x < 1486; x += 26 + Math.floor(rnd() * 18)) {
      stones += `<rect x="${x}" y="${964 + r * 16}" width="${n(18 + rnd() * 16)}" height="13" ` +
                `fill="#1e2226" opacity="${n(0.35 + rnd() * 0.4, 3)}"/>`;
    }
  }
  /* fenêtre : verre chaud, meneaux, allège éclairée */
  const win = (x, y, w, h, o = 1, cols = 2, rows = 2) => {
    let m = '';
    for (let i = 1; i < cols; i++)
      m += `<path d="M ${x + (w / cols) * i} ${y} L ${x + (w / cols) * i} ${y + h}" stroke="#0c0e10" stroke-width="4"/>`;
    for (let j = 1; j < rows; j++)
      m += `<path d="M ${x} ${y + (h / rows) * j} L ${x + w} ${y + (h / rows) * j}" stroke="#0c0e10" stroke-width="4"/>`;
    return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="url(#gw)" opacity="${o}"/>` +
           `<rect x="${x}" y="${y}" width="${w}" height="${h * 0.30}" fill="#3a2a17" opacity="0.42"/>` +
           m +
           `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="none" stroke="#0b0d0f" stroke-width="5"/>` +
           `<rect x="${x - 6}" y="${y + h}" width="${w + 12}" height="7" fill="#2a2f34"/>`;
  };

  return svg(W, H, `
  <defs>
    ${defsCommon('C')}
    <linearGradient id="gw" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#ffdcac"/><stop offset="60%" stop-color="${PAL.ember}"/>
      <stop offset="100%" stop-color="#a35f23"/>
    </linearGradient>
    <linearGradient id="wd" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#33291f"/><stop offset="100%" stop-color="#14171a"/>
    </linearGradient>
    <linearGradient id="rs" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#e8e4dc"/><stop offset="100%" stop-color="#9ba1a7"/>
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="${PAL.ember}" stop-opacity="0.42"/>
      <stop offset="100%" stop-color="${PAL.ember}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="pool" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="${PAL.emberL}" stop-opacity="0.55"/>
      <stop offset="100%" stop-color="${PAL.ember}" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <!-- sapins d'échelle, derrière le bâti -->
  <g opacity="0.9">
    <path d="${firLine(rnd, { w: 620, groundY: 972, count: 7, hMin: 150, hMax: 260 })}" fill="#0e1114"/>
    <g transform="translate(1420 0)">
      <path d="${firLine(rnd, { w: 500, groundY: 984, count: 6, hMin: 140, hMax: 240 })}" fill="#0e1114"/>
    </g>
  </g>

  <!-- halo diffus autour des ouvertures -->
  <ellipse cx="960" cy="812" rx="560" ry="250" fill="url(#glow)"/>

  <!-- volume principal -->
  <path d="M 640 720 L 1280 720 L 1280 968 L 640 968 Z" fill="url(#wd)"/>
  ${planks}
  <!-- avancée -->
  <path d="M 1244 782 L 1462 782 L 1462 968 L 1244 968 Z" fill="#121517"/>
  <!-- toiture : neige sur le dessus, sous-face sombre -->
  <path d="M 612 726 L 960 578 L 1308 726 L 1268 746 L 960 614 L 652 746 Z" fill="url(#rs)"/>
  <path d="M 652 746 L 960 614 L 1268 746 L 1268 768 L 960 636 L 652 768 Z" fill="#0b0d0e"/>
  <path d="M 1220 788 L 1352 724 L 1486 788 L 1460 800 L 1352 750 L 1246 800 Z" fill="url(#rs)"/>
  <path d="M 1246 800 L 1352 750 L 1460 800 L 1460 814 L 1352 766 L 1246 814 Z" fill="#0b0d0e"/>
  <!-- cheminée -->
  <rect x="1052" y="596" width="44" height="90" fill="#1c2024"/>
  <rect x="1044" y="588" width="60" height="14" fill="#e8e4dc"/>
  <!-- fumée : trois volutes très diffuses -->
  <g filter="url(#hazeC)">
    <path d="M 1074 588 C 1056 528 1098 500 1080 448 C 1066 408 1102 384 1094 348"
          stroke="#cfd3d6" stroke-width="26" fill="none" stroke-linecap="round" opacity="0.13"/>
    <path d="M 1074 588 C 1062 540 1092 512 1082 470"
          stroke="#e2e5e7" stroke-width="15" fill="none" stroke-linecap="round" opacity="0.16"/>
    <path d="M 1080 470 C 1064 420 1112 396 1100 340 C 1092 302 1122 284 1118 252"
          stroke="#cfd3d6" stroke-width="34" fill="none" stroke-linecap="round" opacity="0.07"/>
  </g>

  <!-- ouvertures -->
  ${win(700, 768, 148, 126, 1, 2, 2)}
  ${win(884, 752, 212, 154, 1, 3, 2)}
  ${win(1132, 768, 114, 126, 0.9, 2, 2)}
  ${win(1290, 834, 72, 90, 0.78, 1, 2)}
  ${win(1392, 834, 44, 90, 0.6, 1, 2)}

  <!-- balcon filant -->
  <rect x="646" y="900" width="632" height="9" fill="#241c13"/>
  ${Array.from({ length: 26 }, (_, i) =>
      `<rect x="${656 + i * 24}" y="909" width="5" height="44" fill="#1b1510"/>`).join('')}
  <rect x="640" y="951" width="646" height="13" fill="#161a1d"/>

  <!-- soubassement de pierre -->
  <path d="M 616 964 L 1486 964 L 1486 1012 L 616 1012 Z" fill="#101315"/>
  ${stones}

  <!-- la lumière des fenêtres tombe sur la neige -->
  <ellipse cx="774" cy="1016" rx="200" ry="70" fill="url(#pool)"/>
  <ellipse cx="990" cy="1020" rx="260" ry="82" fill="url(#pool)"/>
  <ellipse cx="1190" cy="1024" rx="170" ry="62" fill="url(#pool)"/>

  <!-- congère avant -->
  <path d="M 0 1006 C 300 966 520 1000 780 984 C 1060 966 1320 1002 1560 980 C 1740 964 1860 986 1920 976 L 1920 1080 L 0 1080 Z"
        fill="#ddd9d1"/>
  <path d="M 0 1032 C 340 1002 640 1030 940 1016 C 1240 1002 1560 1030 1920 1010 L 1920 1080 L 0 1080 Z"
        fill="#3f4348" opacity="0.4"/>
  ${grainOverlay(W, H, 0.06, 'C')}`);
}

/* — 6. congère de premier plan (calque le plus proche) -------------------- */
export function drift () {
  return svg(W, H, `
  <defs>
    ${defsCommon('D')}
    <linearGradient id="dg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#f1ede6"/><stop offset="100%" stop-color="#8f8d89"/>
    </linearGradient>
  </defs>
  <path d="M 0 940 C 260 880 460 942 720 918 C 980 894 1180 950 1420 924 C 1640 900 1820 940 1920 918 L 1920 1080 L 0 1080 Z"
        fill="url(#dg)"/>
  <path d="M 0 1000 C 320 962 600 1002 900 986 C 1220 968 1560 1004 1920 986 L 1920 1080 L 0 1080 Z"
        fill="#4a4843" opacity="0.35"/>
  ${grainOverlay(W, H, 0.09, 'D')}`);
}

/* — vue de fenêtre : petit panorama réutilisé dans les intérieurs --------- */
export function windowView (seed = 314, w = 900, h = 700) {
  const rnd = rng(seed);
  const mk = (baseY, amp, peaks, fill, op) => {
    const raw = fractal(rnd, 6, 0.52);
    const env = envelope(raw.length, peaks);
    const hs = raw.map((v, i) => Math.min(1, (0.3 + v * 0.7) * env[i]));
    const p = ridgePath(hs, { w, baseY, amp });
    return `<path d="${p.closed}" fill="${fill}" opacity="${op}"/>`;
  };
  return svg(w, h, `
  <defs>
    <linearGradient id="wv" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#131a22"/><stop offset="58%" stop-color="#414852"/>
      <stop offset="100%" stop-color="#b6a68f"/>
    </linearGradient>
  </defs>
  <rect width="${w}" height="${h}" fill="url(#wv)"/>
  ${mk(430, 250, [{ x: 0.2, h: 0.9, w: 0.15 }, { x: 0.6, h: 1, w: 0.13 }, { x: 0.9, h: 0.7, w: 0.14 }], '#8d949b', 0.55)}
  ${mk(540, 230, [{ x: 0.1, h: 0.8, w: 0.16 }, { x: 0.45, h: 1, w: 0.12 }, { x: 0.82, h: 0.86, w: 0.13 }], '#454c54', 0.9)}
  ${mk(650, 190, [{ x: 0.3, h: 0.9, w: 0.18 }, { x: 0.75, h: 1, w: 0.15 }], '#20252a', 1)}`);
}
