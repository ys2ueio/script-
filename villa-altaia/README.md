# Villa Altaïa

Site vitrine immersif pour une villa de luxe en montagne. Le visiteur descend
des sommets enneigés jusqu'au feu du salon en un seul mouvement de défilement :
quand il arrive au formulaire, il a le sentiment d'avoir déjà parcouru la maison.

**Ouvrir :** `villa-altaia/index.html` — aucune étape de build, aucun serveur
requis (les bibliothèques et les visuels sont versionnés).

```
python3 -m http.server 8000 --directory villa-altaia   # facultatif
```

---

## Ce qui compose la descente

| Chapitre | Contenu | Traitement |
|---|---|---|
| Sommets | vidéo de brume + six calques de parallaxe | plein écran aimanté |
| Arrivée | le chalet vu de la congère | recadrage lié au scroll |
| Salon | baie ouest + foyer de pierre | photographie d'intérieur |
| Suite | baie panoramique sur les crêtes | idem |
| Spa | bassin lumineux | idem |
| Terrasse | crêtes au couchant, brasero | idem |
| Plan | plan d'architecte tracé au fil du scroll | SVG animé |
| Prestations | six cartes | Vanilla Tilt |
| Séjourner | chiffres et contact | — |

## Structure

```
villa-altaia/
├── index.html                  document unique, plan SVG en ligne
├── assets/
│   ├── css/villa.css           jetons, mise en page, états réduits
│   ├── js/
│   │   ├── scene.js            travelling WebGL (Three.js)
│   │   ├── plan.js             tracé progressif du plan
│   │   ├── lazy.js             IntersectionObserver
│   │   └── main.js             orchestration GSAP + ScrollTrigger
│   ├── img/                    15 illustrations SVG générées
│   ├── video/mist.webm         boucle de brume, 8 s, sans raccord
│   └── vendor/                 three.js · gsap · ScrollTrigger · vanilla-tilt
└── tools/                      générateurs (voir plus bas)
```

## Techniques

**Travelling WebGL** — `assets/js/scene.js`. Cinq crêtes fractales triangulées
prises dans un `FogExp2`, de la neige et des braises en `Points`. Un unique
ScrollTrigger transmet la progression globale (0 → 1) ; la caméra descend, le
champ se resserre, le brouillard passe du bleu des sommets à l'ambre du salon.
La cible est lissée image par image : le mouvement ne colle jamais au scroll.

**Parallaxe** — les six calques du hero (ciel, sommets lointains, crêtes,
forêt, chalet, congère) portent un `data-depth` ; une timeline scrubbée leur
donne à chacun sa vitesse et son échelle.

**Vidéo** — `<video autoplay muted loop playsinline>` en `mix-blend-mode: screen`
au-dessus du ciel peint : la brume s'ajoute au dégradé au lieu de l'assombrir.
Elle n'est jouée que lorsqu'elle est visible (IntersectionObserver) et l'affiche
`hero-poster.jpg` prend le relais si la lecture automatique est refusée.

**Plan tracé au scroll** — `assets/js/plan.js`. Chaque tracé devient un
pointillé de sa propre longueur (`getTotalLength`) dont le décalage est réduit
à zéro. Les groupes s'enchaînent : gros œuvre, refends, agencement, cotes,
nomenclature.

**Chargement différé** — `assets/js/lazy.js` précharge hors document 400 px
avant l'entrée dans le cadre, puis attend `decode()` : l'image apparaît nette,
sans à-coup de mise en page. Le cadre porte pendant ce temps un dégradé
anthracite/ambre, jamais un vide blanc.

**Cartes** — Vanilla Tilt (7° max, sans WebGL), activé seulement sur pointeur
fin ; un reflet radial suit le curseur via deux variables CSS.

### Deux pièges rencontrés, et leur correctif

- `scroll-behavior: smooth` sur `html` **casse ScrollTrigger** : son recalcul
  remet brièvement le scroll à zéro, or le défilement fluide natif est
  asynchrone — toutes les bornes se retrouvaient décalées de la position
  courante et les timelines sautaient à 100 %. La propriété a été retirée ;
  les ancres sont adoucies en JavaScript (`main.js`, §0).
- L'aimantation CSS gêne le même recalcul : `scroll-snap-type` est suspendu
  pendant `refreshInit` puis rétabli sur `refresh`.

## Accessibilité

`prefers-reduced-motion` désactive le WebGL, l'aimantation et toutes les
transitions ; les textes et les images sont rendus dans leur état final. Le
plan reste dessiné, la vidéo est mise en pause. Navigation au clavier, lien
d'évitement, `aria-current` sur le chapitre courant, textes alternatifs
descriptifs. Sans JavaScript, la page reste entièrement lisible.

## Direction artistique

Deux tons, pas un de plus : bois chaud / beige (`#cdbca6`, `#a8865f`) et
anthracite (`#0b0d0f` → `#3a4048`), avec l'ambre `#d99a5c` comme seule couleur
d'accent. Cormorant Garamond en titrage, Jost en labeur, repli sur des piles
système si les fontes ne se chargent pas. Ombres portées en trois strates,
`object-fit: cover` sur tous les visuels plein cadre.

## Régénérer les visuels

Les fichiers produits sont versionnés ; ces scripts ne servent qu'à les
retoucher.

```bash
node tools/build-art.mjs        # les 15 SVG (aucune dépendance)

npm i playwright
CHROMIUM_PATH=/chemin/vers/chromium node tools/make-video.mjs   # mist.webm + affiche
```

`tools/art-lib.mjs` porte les primitives (bruit fractal, crêtes, sapins,
projection en perspective à un point de fuite) ; `art-outdoor.mjs` les scènes
extérieures, `art-interior.mjs` les intérieurs. Ceux-ci suivent une règle
unique : **une seule source lumineuse dominante par pièce**, tout le reste en
silhouette avec un simple liseré — c'est ce qui donne la lecture d'une
photographie d'architecture plutôt que d'un aplat.

## Remplacer par de vraies photographies

Chaque visuel est référencé par `data-src` dans `index.html`. Déposer les
fichiers dans `assets/img/` et changer les chemins suffit : le chargement
différé, le recadrage `cover` et le zoom lié au scroll s'appliquent tels quels.
Pour la vidéo, ajouter une source MP4 avant la source WebM :

```html
<source src="assets/video/mist.mp4" type="video/mp4">
```

## Licences

Three.js (MIT), GSAP + ScrollTrigger (licence standard « no charge » de
GreenSock), Vanilla Tilt (MIT) sont vendus dans `assets/vendor/`. Les
illustrations et la vidéo sont générées par les scripts de `tools/`.

Villa fictive : nom, adresse et coordonnées sont des exemples.
