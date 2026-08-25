# Tapis & Cotes

Simulateur de poker **No-Limit Texas Hold'em 6-max** avec coach intégré, en français.
Un seul fichier, aucune dépendance : ouvre `index.html` dans un navigateur.

## Ce que ça fait

Tu joues contre 5 adversaires aux profils distincts (serré-agressif, suiveur passif,
large-agressif, imprévisible…), 100 blindes de tapis, blindes 25/50, recave automatique.

À **chaque** décision, le rail de droite affiche :

- ton **équité réelle**, calculée par simulation Monte-Carlo (2 200 tirages) contre le
  nombre exact d'adversaires encore en jeu ;
- la **cote du pot** — le pourcentage d'équité qu'il te faut pour que suivre soit rentable ;
- l'**espérance de gain** du suivi en jetons ;
- tes **outs**, comptés comme un joueur les compte vraiment (une paire sur le board ne
  compte pas, une surcarte oui) ;
- la **ligne recommandée** et pourquoi, puis une **note de ta décision** une fois jouée.

Neuf leçons progressives (déroulé d'une main, classement, position, cote du pot, règle des
2 et 4, ranges d'ouverture et score de Chen, sizing, bluff/semi-bluff, erreurs classiques)
et un glossaire sont dans l'onglet **Leçons**.

Raccourcis : `F` se coucher · `C` parole/suivre · `R` relancer · `Espace` main suivante.

Deux réglages utiles pour apprendre : **Cartes ouvertes** (voir le jeu des adversaires
pendant la main) et **Coach** (le couper pour se tester en conditions réelles).

## Vérifications

Le moteur a été testé dans un navigateur réel :

- **Évaluateur** — énumération exhaustive des 2 598 960 mains de 5 cartes ; les 9 catégories
  tombent exactement sur les fréquences connues (1 302 540 hauteurs … 40 quintes flush).
  Cas limites couverts : roue A-2-3-4-5, couleur contre full à 7 cartes, kickers, égalités.
- **Pots annexes** — cas étagés vérifiés à la main, plus 3 000 répartitions aléatoires où la
  somme des pots égale toujours la somme des mises.
- **Partie complète** — 120 mains jouées automatiquement (668 décisions, tapis et pots
  annexes inclus) : conservation des jetons vérifiée en continu, aucune violation, aucune
  erreur JavaScript.

Les fonctions internes sont exposées sur `window.TapisCotes` pour inspection depuis la
console du navigateur (`evaluate`, `equity`, `countOuts`, `chen`, `buildPots`, `G`…).

## Limites assumées

Les seuils préflop reposent sur le **score de Chen**, un raccourci pédagogique et non une
solution de solveur : il évite l'essentiel des erreurs de débutant, il ne joue pas la GTO.
Les équités sont calculées contre des mains adverses **aléatoires**, pas contre une range
estimée — le chiffre est donc légèrement optimiste face à un adversaire qui ne mise que
ses bonnes mains.
