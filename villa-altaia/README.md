# Villa Altaïa — site one-page

Site vitrine plein écran pour une villa de luxe en montagne, dans un registre
photographique cinématique : vraies photos plein cadre, overlay sombre, serif
élégant sur palette beige/anthracite. Aucun paysage dessiné en CSS ou SVG.

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `index.html` | Structure, 7 sections plein écran, formulaire de demande |
| `styles.css` | Palette, typographie, scroll-snap, cartes 3D, responsive |
| `script.js` | GSAP + ScrollTrigger, Vanilla-Tilt, IntersectionObserver, formulaire |

Ouvrir `index.html` dans un navigateur suffit. Pour un test propre :
`npx http-server -p 8080 .` puis <http://127.0.0.1:8080>.

## Sections

`01 Sommets` (hero) · `02 Salon` · `03 Suite` · `04 Spa` · `05 Terrasse` ·
`06 Plan` (4 cartes 3D) · `07 Séjourner` (formulaire).

Chacune occupe `100vh`, s'aligne en `scroll-snap-align: start` et porte sa
propre photographie.

## Photographies

Les images viennent d'Unsplash, en URL directe :

```
https://images.unsplash.com/photo-<id>?auto=format&fit=crop&w=<largeur>&q=80
```

`source.unsplash.com`, cité dans le brief initial, a été retiré par Unsplash et
ne sert plus d'images ; les URL `images.unsplash.com` sont l'équivalent stable,
avec en prime le redimensionnement et la conversion de format automatiques.

Identifiants utilisés, un par section :

| Section | Photo |
| --- | --- |
| Sommets | `1506905925346-21bda4d32df4` |
| Salon | `1600585154340-be6161a56a0c` |
| Suite | `1611892440504-42a792e24d32` |
| Spa | `1540555700478-4be289fbecef` |
| Terrasse | `1566073771259-6a8506099945` |
| Plan | `1518780664697-55e3ad937233` |
| Séjourner | `1519681393784-d120267933ba` |
| Cartes chambres | `1505693416388-ac5ce068fe85`, `1618773928121-c32242e63f39`, `1571896349842-33c89424de2d`, `1618221195710-dd6b41faaea6` |

Trois mécanismes encadrent ces images :

- **Largeur adaptative** — `widthFor()` choisit 1200 à 2560 px selon la taille
  d'écran et la densité de pixels, pour ne pas tirer une photo 2560 px sur mobile.
- **Chargement différé** — un `IntersectionObserver` (`rootMargin: 150%`) pose le
  `src` quand la section approche. Seule la photo du hero est préchargée.
- **Chaîne de repli** — chaque `<img>` porte un attribut `data-fallback` listant
  des photos de secours ; en cas d'erreur réseau, la suivante est chargée.

L'overlay imposé sur chaque photo est
`linear-gradient(rgba(0,0,0,0.4), rgba(0,0,0,0.7))`, complété d'un grain animé
et d'un vignettage pour l'aspect argentique.

## Animations

- **Hero** — zoom arrière de la photo, `scale` 1.15 → 1 en 2,5 s (`power3.out`),
  puis le titre apparaît mot par mot en fondu et translation verticale, suivi du
  sur-titre, de l'accroche et des boutons.
- **Sections** — parallaxe de la photo en `scrub`, titres et textes révélés à
  l'entrée dans le viewport (`once: true`).
- **Cartes** — inclinaison 3D au survol via Vanilla-Tilt (`max: 12°`, reflet
  0.28), désactivée sur écran tactile.
- **Divers** — barre de progression de lecture, pastilles de navigation
  latérales, barre supérieure compacte au défilement.

Les états initiaux masqués ne s'appliquent que si GSAP et ScrollTrigger sont
réellement chargés (classe `is-ready`) : si les CDN sont inaccessibles, la page
s'affiche entièrement, sans animation. `prefers-reduced-motion` coupe les
animations et le scroll-snap.

## Dépendances (CDN)

GSAP 3.12.5, ScrollTrigger 3.12.5, Vanilla-Tilt 1.8.1 (cdnjs) ; polices
Cormorant Garamond et Jost (Google Fonts).

## Contenu

Les textes, tarifs, adresses et l'email `reservations@villa-altaia.example`
sont fictifs : la villa est un support de démonstration.
