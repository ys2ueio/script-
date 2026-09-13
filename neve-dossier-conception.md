# Névé — Dossier de conception

Palier 1, un seul plan continu de 5 secondes. Marque inventée. Site en français.
Toute ligne de texte ci-dessous part telle quelle dans la page.

## 1. La prémisse de marque

**Névé** est un vrai mot de montagne : la neige tassée des hauteurs, celle qui ne fond
jamais tout à fait. C'est le point le plus haut, le plus silencieux, là où l'air est le
plus fin. Une seule idée porte tout le site : le luxe ici est ce qu'il n'y a pas. Pas de
voisin, pas de route, pas de bruit. Chaque section, le moment interactif et la dernière
ligne servent cette idée. Une section qui ne la sert pas ne monte pas sur la page.

## 2. La palette en tokens CSS

Prélevée du monde du film : ardoise froide, neige, brume, granite mouillé, bleu glacier.

```css
:root{
  --canvas:#0E1318;        /* fond de page, teinté vers le froid du film, jamais noir pur */
  --panel:#151C23;         /* cartes et surfaces surélevées */
  --accent:#8FC4DA;        /* le bouton et deux moments d'emphase */
  --accent-hover:#AEDAEB;
  --accent-muted:rgba(143,196,218,.22);
  --text-secondary:#9FACB5;
  --text-primary:#EDF1F3;
}
```

Contrastes calculés : texte secondaire 8,0:1 sur le fond, accent 9,7:1, texte foncé sur
bouton accent 9,7:1. Tous au-dessus du plancher.

## 3. Le trio typographique

- **Titres : Bricolage Grotesque** (400, 600, 800). Lettre taillée, un peu irrégulière,
  comme la pierre. Ni Inter ni Roboto.
- **Texte : Newsreader** (300, 400). Sérif calme et lisible, qui laisse respirer.
- **Étiquettes : IBM Plex Mono** (400). Précision d'instrument de montagne.

## 4. La carte des bandes

Héros de 560vh, soit 460vh de course de défilement. Plateaux de 83 à 92vh, rampes de 9vh.
Valeurs de départ, validées plus tard par le test de flick.

| Bande | Plage | Moment du film | Texte (tel quel) | Entrée |
|---|---|---|---|---|
| 1 | 0.00 à 0.22 | Au-dessus de la mer de nuages, sommets qui percent, lumière froide | « Le bruit s'arrête ici. » / « 3 200 mètres. Rien ne monte aussi haut. » | Drift-down : les mots se déposent vers le bas, comme la descente qui commence |
| 2 | 0.26 à 0.50 | Entrée dans la couche : brume sur l'objectif, gouttes, un instant de flou blanc | « On perd le monde de vue. » / « Quelques secondes de blanc, et c'est tout. » | Blur-to-sharp : le texte sort du flou en même temps que l'image |
| 3 | 0.54 à 0.76 | Sortie sous les nuages, air clair, la vallée s'ouvre, la villa au loin | « Et en dessous, personne. » / « Une maison, une paroi, la neige. » | Approach-from-depth : la ligne grandit vers vous, comme la villa qui approche |
| 4 | 0.80 à 1.00 | La villa au repos, en bas au centre, ciel libre au-dessus | kicker « 1 840 M » / « Névé » / « Une villa seule sur son replat de pierre. Six personnes. Aucun voisin. » / bouton « Demander mes dates » | Word-by-word rise, trois arrivées en une bande : titre, sous-titre, bouton |

La bande 1 s'ouvre déjà assemblée grâce à une rampe de chargement unique. Les autres
sont pilotées par le défilement et réversibles.

## 5. Le bloc du héros fixe (téléphones, mouvement réduit)

- Titre : « Névé »
- Sous-titre : « Une villa seule à 1 840 mètres. Le bruit s'arrête en dessous. »
- Bouton : « Demander mes dates »

Composé sur l'image de fin du film, pas sur la première.

## 6. Le plan des sections sous le héros

Chaque section pousse vers une seule action : `#dates`. Aucune section voisine ne partage
le même squelette de mise en page.

**1. Le manifeste** (texte pleine largeur, courbes de niveau qui se dessinent)
- Titre : « Le luxe, ici, c'est ce qu'il n'y a pas. »
- Texte : « Pas de voisin à trente minutes de marche. Pas de route qui passe. Pas de
  musique dans le salon si vous n'en mettez pas. Névé n'ajoute rien. Elle enlève. »

**2. Le silence, mesuré** (le moment interactif, appui maintenu)
- Étiquette : « MESURÉ SUR PLACE »
- Titre : « Appuyez. Et laissez le bruit descendre. »
- Texte : « 62 décibels, c'est une rue un mardi matin. 21, c'est le névé au-dessus de la
  villa. Maintenez le bouton et regardez le chiffre tomber. »
- Bouton : « Maintenir »
- État d'arrivée : « 21 dB. Voilà ce que vous venez chercher. »
- Mouvement réduit : état final affiché tout de suite, sans appui.

**3. La maison** (image de section à gauche, liste à droite, lignes alignées sur la ligne de base)
- Titre : « Ce qu'il y a dedans »
- « Trois chambres, six lits. Personne ne dort dans le salon. »
- « Une cheminée qui tire vraiment, et le bois est déjà monté. »
- « Un poêle finlandais, et une fenêtre qui donne sur la paroi. »
- « Cuisine complète, linge fourni, ménage compris à la sortie. »

**4. Comment ça se passe** (trois étapes, numéros en mono, aucune image, traitement égal)
1. « Vous demandez vos dates. » / « Une réponse le jour même, écrite par une personne. »
2. « On vous appelle une fois. » / « Dix minutes, pour vérifier que le lieu vous va vraiment. »
3. « Vous arrivez. » / « On ouvre, on montre, on vous laisse tranquille. »

**5. Ce qui bloque les gens** (FAQ, réponses aux vraies objections trouvées)
- « 1 180 € la nuit, c'est cher. » → « Oui. Divisé par six, c'est 197 € par personne, bois
  et ménage compris. Si vous cherchez moins cher, la vallée en dessous en est pleine, et
  vous y serez très bien. »
- « Et si le wifi ne marche pas ? » → « La fibre monte jusqu'à la villa et il y a un
  routeur de secours. Cela dit, la moitié des gens qui viennent ici le coupent au bout
  d'un jour. »
- « Les bonnes dates sont prises un an à l'avance ? » → « Les semaines de février, oui.
  Le reste de l'année s'ouvre à trois mois. Janvier et mars sont les plus calmes, et les
  moins chers. »
- « On est loin de tout ? » → « Vingt minutes de route depuis le village, puis huit
  minutes à pied depuis le parking déneigé. On monte vos bagages. »
- « Qui répond si quelque chose ne va pas ? » → « Une personne, un numéro, joignable de
  7h à 23h pendant tout votre séjour. Pas de formulaire, pas de plateforme. »

**6. Ceux qui sont venus** (trois citations, traitement égal)
- « On a dormi neuf heures par nuit. On ne fait jamais ça. » — Claire et Simon, février
- « Le deuxième jour, on a arrêté de parler fort. » — Marc, décembre
- « J'ai coupé mon téléphone le dimanche. Je l'ai rallumé dans le train. » — Léa, mars

**7. Le prix, dit franchement** (bande large, chiffres en display)
- Titre : « Ce que ça coûte »
- « Basse saison, 640 € la nuit. Haute saison, 1 180 €. Trois nuits minimum. »
- « Bois, linge et ménage compris. Pas de frais de service. Pas de caution à l'arrivée. »

**8. La demande de dates** (l'unique action, le formulaire, ancre `#dates`)
- Titre : « Demandez vos dates »
- Sous-titre : « Trois champs, une réponse le jour même. »
- Champs : « Vos dates » (ex. 12 au 16 février) / « Votre email » / « Vous êtes combien ? »
- Bouton : « Envoyer ma demande »
- Succès : « C'est noté. Vous avez une réponse aujourd'hui. »
- Traitement : état de succès en JavaScript seul, sans envoi réel. C'est une démonstration,
  et le site le dit en toutes lettres sous le formulaire.
- Sous le formulaire : « Site de démonstration. Ce formulaire n'envoie rien à personne. »

**9. Le pied de page**
- « Névé est une marque fictive, créée pour une démonstration. La villa, les avis et les
  prix n'existent pas. Le film et les images ont été générés par intelligence artificielle. »

## 7. Le plan de la couche vectorielle

- **Courbes de niveau** : trois tracés SVG dessinés à la main, qui se dessinent au
  défilement dans le manifeste. La carte de la montagne, jamais une décoration posée.
- **L'échelle d'altitude** : les graduations de l'altimètre dans le héros, en SVG.
- **Le trait de section** : une seule courbe fine entre les sections, jamais une barre.
- **Particules** : neige très fine qui dérive dans la couche d'ambiance fixe, au niveau du
  murmure, cycle de 70 secondes, jamais visible d'un coup.
- Tout respecte le mouvement réduit : état final affiché, moteurs arrêtés.

## 8. L'élément signature

**L'altimètre.** Un vrai chiffre d'altitude, en mono, dans une pastille floutée à gauche du
héros. Il descend de 3 200 m à 1 840 m au rythme exact du défilement, avec ses graduations
qui défilent à côté. Il est lié au film, pas posé dessus. Retirez-le et la page perd son
instrument : c'est là que passe tout le budget d'audace. Le reste de la page reste calme
pour qu'il se voie.

## 9. La liste d'ingénierie

Le standard complet, sans rien oublier : vidéo chargée en Blob derrière un anneau de
progression honnête, lissage du temps affiché normalisé sur la durée de trame, recherches
vidéo mises en file, écritures DOM seulement au changement, rythme des bandes validé par le
test de flick, système de lisibilité à quatre couches (voile global, voile par bande, ombre
de texte, pastille pour le petit texte), les cinq portes du héros fixe maintenues vivantes
par des écouteurs de changement, page complète même sans la vidéo, et le plancher de qualité
entier. Plus le standard « tout le site animé » : traits SVG qui se dessinent, particules au
murmure, une entrée unique par moment, de l'atténuation partout.

## 10. La porte du texte

Chaque ligne visible ci-dessus part telle quelle. La page construite doit passer la revue :
zéro tiret cadratin, zéro mot de catalogue, et le balayage des tics d'écriture automatique.
Les procédés voulus de la marque restent : la triade « Six personnes. Aucun voisin. » et la
frappe courte « Elle enlève. » sont du métier, pas des tics.
