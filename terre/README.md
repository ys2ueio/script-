# La Terre — site éducatif

Site statique d'une page consacré à la planète Terre, en trois sections :

1. **Ce qui l'entoure** — l'atmosphère, la Lune, le système solaire
2. **La Planète** — la structure interne, les océans, les continents
3. **Ce qu'elle contient** — la biodiversité, les écosystèmes, l'humanité

## Ouvrir le site

Aucune étape de compilation : il suffit d'ouvrir `index.html`. Pour un rendu
identique à la production (chemins relatifs, images), passer par un serveur
local :

```sh
python3 -m http.server 8000
# puis http://localhost:8000/terre/
```

## Structure

```
terre/
├── index.html          page unique
├── css/style.css       feuille de style (aucune dépendance externe)
└── img/*.svg           onze illustrations
```

## Choix techniques

- **HTML et CSS uniquement**, sans JavaScript. Le défilement fluide utilise
  `scroll-behavior`, la barre de progression et les apparitions au défilement
  reposent sur les animations pilotées par le scroll (`animation-timeline`),
  encadrées par `@supports` : là où elles ne sont pas gérées, le contenu
  s'affiche normalement.
- **Aucune ressource distante** — ni police, ni CDN, ni image externe. Le site
  fonctionne hors ligne et ne dépend d'aucun tiers.
- **Illustrations en SVG**, écrites à la main ou générées, donc nettes à toute
  taille et lisibles par les lecteurs d'écran via `role="img"` et `aria-label`.
  Les contours du globe, de la carte du monde et de la carte nocturne
  proviennent des données **Natural Earth** (domaine public), au 1:110 m,
  reprojetées puis simplifiées.
- **Accessibilité** : structure sémantique, lien d'évitement, contrastes
  soutenus, styles de focus visibles, et respect de `prefers-reduced-motion`.
- **Responsive** jusqu'à 360 px ; sur petit écran, les schémas denses restent
  lisibles grâce à un défilement horizontal plutôt qu'une réduction illisible.

## Sources des données

NASA, NOAA, USGS, FAO, UICN, IPBES, Catalogue of Life. Certaines valeurs sont
des estimations et évoluent avec la recherche.
