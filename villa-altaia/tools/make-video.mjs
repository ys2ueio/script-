#!/usr/bin/env node
/* ---------------------------------------------------------------------------
 * make-video.mjs — produit la boucle vidéo du hero (brume d'altitude).
 *
 *   npm i playwright && node tools/make-video.mjs
 *
 * La scène (tools/scene-mist.html) est périodique : render(t), t ∈ [0,1[.
 * On capture N images réparties sur une période puis on encode en VP8/WebM
 * avec le ffmpeg fourni par Playwright — la boucle est donc sans raccord.
 * Le fichier produit est versionné : aucune étape de build n'est nécessaire
 * pour servir le site.
 * ------------------------------------------------------------------------- */
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, existsSync, readdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const FPS = 24, SECONDS = 8, FRAMES = FPS * SECONDS;
const OUT = join(here, '..', 'assets', 'video', 'mist.webm');

function ffmpegPath () {
  const base = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
  const dir = readdirSync(base).find(d => d.startsWith('ffmpeg-'));
  if (!dir) throw new Error('ffmpeg introuvable dans ' + base);
  return join(base, dir, 'ffmpeg-linux');
}

const tmp = mkdtempSync(join(tmpdir(), 'villa-frames-'));
mkdirSync(dirname(OUT), { recursive: true });

const browser = await chromium.launch({
  /* le conteneur d'exécution fournit déjà un Chromium : CHROMIUM_PATH permet
     de le désigner sans relancer `npx playwright install`. */
  executablePath: process.env.CHROMIUM_PATH || undefined
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(join(here, 'scene-mist.html')).href);

for (let i = 0; i < FRAMES; i++) {
  await page.evaluate(t => window.render(t), i / FRAMES);
  await page.locator('#c').screenshot({
    path: join(tmp, `f${String(i).padStart(4, '0')}.jpg`), type: 'jpeg', quality: 92
  });
  if (i % 24 === 0) process.stdout.write(`  ${i}/${FRAMES}\r`);
}
/* image d'affiche : première image de la boucle, servie avant la vidéo
   et affichée telle quelle si la lecture automatique est refusée. */
await page.evaluate(() => window.render(0));
await page.locator('#c').screenshot({
  path: join(here, '..', 'assets', 'img', 'hero-poster.jpg'), type: 'jpeg', quality: 82
});
await browser.close();

/* Le ffmpeg fourni par Playwright n'embarque que le démuxeur image2pipe :
   les JPEG sont donc concaténés sur son entrée standard. */
const stream = Buffer.concat(
  readdirSync(tmp).sort().map(f => readFileSync(join(tmp, f)))
);
execFileSync(ffmpegPath(), [
  '-y', '-f', 'image2pipe', '-vcodec', 'mjpeg', '-framerate', String(FPS),
  '-i', 'pipe:0',
  '-c:v', 'libvpx', '-b:v', '1500k', '-crf', '30', '-g', String(FPS * 2),
  '-auto-alt-ref', '0', '-an', OUT
], { input: stream, maxBuffer: 1 << 30, stdio: ['pipe', 'inherit', 'inherit'] });

rmSync(tmp, { recursive: true, force: true });
console.log('\n→', OUT, existsSync(OUT) ? 'ok' : 'ÉCHEC');
