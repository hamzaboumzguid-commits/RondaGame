# Ronda Marocaine — Game Design Document (GDD)

Ce document est la référence unique pour les règles du jeu, les décisions produit et les choix techniques. Il évoluera au fil du projet. Toute session de développement (humaine ou Claude Code) doit s'y référer avant de trancher un cas ambigu.

Statut : recueil du besoin terminé, stack technique validée. Scaffolding en cours.

---

## 1. Vision produit

Jeu mobile (iOS + Android, cross-platform) de Ronda marocaine — variante café, 41 points — multijoueur en ligne uniquement, 4 joueurs en 2 équipes de 2, chacun sur son propre téléphone. Accès instantané façon Among Us : pseudo + code de room, sans compte.

Priorités v1 : qualité d'exécution des règles + animations soignées (Derba, Missa) + fluidité du multijoueur temps réel. Aucune fonctionnalité annexe (pas de chat, pas de stats persistantes, pas de mode local/solo) tant que le cœur n'est pas irréprochable.

---

## 2. Règlement du jeu (source de vérité)

### 2.1 Objectif et matériel

- 4 joueurs, 2 équipes de 2 (coéquipiers assis en positions opposées).
- Jeu espagnol de 40 cartes : As(1), 2, 3, 4, 5, 6, 7, Valet(10), Cavalier(11), Roi(12), en 4 couleurs.
- Ordre des valeurs (pour comparaisons Ronda/Tringa et règle du dernier pli) :
  As(1) < 2 < 3 < 4 < 5 < 6 < 7 < Valet(10) < Cavalier(11) < Roi(12)
- Victoire : première équipe à atteindre ou dépasser 41 points, fin de partie immédiate (même en plein milieu d'une manche).

### 2.2 Le Lead (donneur)

- Le Lead distribue les cartes de la manche.
- À chaque nouvelle manche, le Lead passe au joueur situé à la droite du précédent Lead.
- Le Lead est conventionnellement celui qui doit réaliser la dernière capture de la manche (cf. 2.10 bonus/malus dernière carte).

### 2.3 Distribution

Aucune carte posée sur la table au départ. 3 distributions par manche :
1. 4 cartes/joueur (16 cartes)
2. 3 cartes/joueur (12 cartes)
3. 3 cartes/joueur (12 cartes)

Total 40 cartes. Chaque distribution constitue une **petite manche** (sous-manche) avec son propre cycle annonce → jeu → révélation Ronda/Tringa.

### 2.4 Ordre de jeu

Sens horaire, en commençant par le joueur à la droite du Lead. Le Lead joue donc en dernier dans l'ordre des 4.

### 2.5 Annonce Ronda / Tringa

- Une **Ronda** = 2 cartes de même valeur en main. Une **Tringa** = 3 cartes de même valeur en main.
- Détection **automatique** par le système dès la distribution (pas d'action du joueur).
- Une pastille bien visible est affichée à côté du joueur concerné dès la distribution, indiquant **le type d'annonce (« RONDA » ou « TRINGA »)** mais **jamais la valeur**. (Décision 2026-07-12 : révéler le type améliore la lecture du jeu ; initialement le badge était totalement anonyme.)
- La valeur réelle n'est révélée qu'à la fin de la petite manche en cours (après que les 16 ou 12 cartes de cette distribution ont toutes été jouées).

### 2.6 Capturer des cartes

- Une carte en main capture une carte de même valeur sur la table.
- **Capture obligatoire sur jumelle** : si la valeur de la carte jouée est présente sur la table, la capture est **imposée** — il est interdit de poser une carte « à côté » de sa jumelle. Conséquence : la table ne contient jamais deux cartes de même valeur.
- **Capture libre** porte sur le **choix de la carte jouée** : un joueur n'est jamais obligé de jouer une carte capturante s'il préfère en jouer une autre. Mais la carte jouée capture dès qu'elle le peut.
- **Suite ascendante** : la capture d'une valeur emporte aussi toute la suite ascendante de valeurs **présentes sur la table** (ex : table 5-6-7, le joueur pose un 5 → tout part), **quel que soit l'ordre dans lequel les cartes ont été posées** (table 6-2-4-5, pose d'un 4 → le 4, 5 et 6 partent, le 2 reste). La suite se lit vers le haut uniquement (un 4 ne prend pas le 3) et suit l'ordre des rangs de 2.1 (7 est suivi du Valet). Ceci n'est pas une Derba.
- Si aucune capture n'est possible, la carte est simplement posée sur la table (rejoint le tas commun).

### 2.7 La Derba

- Un joueur capture **immédiatement** la carte que son adversaire (joueur suivant dans l'ordre de jeu) vient de poser, avec une carte de même valeur.
- Barème avec surenchère, non cumulatif — seule la dernière Derba de la chaîne compte :
  - 1ère Derba : 1 point
  - 2e Derba immédiate en chaîne (le joueur suivant répond avec la même valeur) : annule le 1 pt, vaut 5 points
  - 3e Derba immédiate en chaîne : annule le 5 pts, vaut 10 points
- **Plafond à 3 Derbas en chaîne (max 10 pts)** : avec 4 exemplaires par valeur dans le jeu (1 posée + 3 réponses possibles), la chaîne ne peut pas aller plus loin.
- La chaîne se rompt dès qu'un joueur ne répond pas immédiatement avec la même valeur (autre action = fin de la chaîne, dernière Derba valide conservée).
- **Derba ≠ capture ordinaire** : capturer une carte posée plusieurs tours auparavant n'est pas une Derba — seule la carte que le joueur précédent *vient* de poser compte.
- **Le paquet suit la surenchère** : le surenchérisseur emporte toutes les cartes de la chaîne (y compris celles déjà ramassées par la Derba précédente et son éventuelle suite) — elles comptent dans le butin de son équipe. La surenchère ne touche pas la table, elle ne peut donc pas déclencher de Missa.

### 2.8 La Missa

- Un joueur vide complètement la table lors d'une capture → 1 point, attribué à son équipe.
- Cumulative avec la Derba (ex : Derba 10 pts + Missa sur la même capture = 11 pts) et cumulative entre elles (plusieurs Missas possibles dans une manche).

### 2.9 Rondas et Tringas — résolution en fin de petite manche

Résolue une fois que toutes les cartes de la distribution en cours (16 ou 12) ont été jouées :

| Situation | Résultat |
|---|---|
| 1 seule Ronda annoncée dans la manche | 1 point immédiat à son équipe (pas de comparaison nécessaire) |
| 2 ou 3 Rondas annoncées | La plus forte Ronda gagne tout (2 pts si 2 Rondas, 3 pts si 3 Rondas). Égalité entre les meilleures → annulation, personne ne marque. |
| 4 Rondas (chaque joueur en a une) | La **plus petite** Ronda gagne, 4 points. Si la plus petite est partagée par plusieurs joueurs → ces Rondas s'annulent, on compare la valeur suivante ; la première Ronda non contestée (non-égalité) remporte les 4 pts. Si aucun gagnant ne se dégage → 0 point. |
| Tringa présente | Une Tringa bat toujours toute Ronda, quelle que soit sa valeur. Vaut 5 points + 1 point bonus si elle bat une Ronda (= 6 pts total). Si plusieurs Tringas, la **plus petite** gagne les 5(+1) points, les autres ne rapportent rien. |

Comparaisons de valeur : utiliser l'ordre de 2.1.

### 2.10 Comptage du butin (fin de manche complète, 40 cartes)

- Chaque équipe compte les cartes capturées au total sur la manche (3 petites manches confondues).
- Équipe > 20 cartes → marque (nombre de cartes − 20) points. Ex : 24 cartes → 4 pts.
- 20-20 → 0 point pour tout le monde (cas impossible arithmétiquement sauf ex-aequo à 20/20, à valider en implémentation — total = 40 donc l'autre équipe a aussi 20).
- **Cartes restantes non capturées sur la table en toute fin de manche** (après la 40e carte jouée) : attribuées à l'équipe du **dernier joueur ayant réalisé une capture**, peu importe si c'est le Lead ou non.

### 2.11 Bonus/malus de dernière capture

- Si la toute dernière capture de la manche est réalisée avec un **Roi (12)** → +5 points pour l'équipe qui capture.
- Si la toute dernière capture de la manche est réalisée avec un **As (1)** → +5 points pour l'équipe **adverse**.
- Rappel : le Lead est censé faire cette dernière capture, mais rien n'empêche que ce soit un autre joueur dans les faits ; le bonus/malus s'applique à qui capture réellement en dernier.

### 2.12 Récapitulatif des points

| Action | Points |
|---|---|
| Ronda seule | 1 |
| 2 Rondas (la meilleure gagne) | 2 |
| 3 Rondas (la meilleure gagne) | 3 |
| 4 Rondas (la plus petite gagne) | 4 |
| Tringa | 5 |
| Tringa contre une Ronda | 6 (5+1) |
| Derba (1ère) | 1 |
| Derba — 1ère surenchère | 5 |
| Derba — 2e surenchère (max) | 10 |
| Missa | 1 (cumulable) |
| Butin | nb cartes − 20 (si > 20) |
| Dernière capture avec un Roi (12) | +5 |
| Dernière capture avec un As (1) | +5 pour l'équipe adverse |

---

## 3. Décisions produit (issues du recueil de besoin)

### 3.1 Multijoueur / rooms
- Style Among Us : un joueur crée une room (code généré), les autres rejoignent avec pseudo + code. Aucun compte requis, identité éphémère le temps de la session.
- Lobby pré-partie : chaque joueur choisit explicitement son équipe (bouton "rejoindre équipe A / équipe B"), 2 places par équipe.
- Partie 100% en ligne, chacun sur son propre appareil. Pas de mode pass-and-play local, pas de mode solo/bots en v1.
- **Pas de gestion de reconnexion en v1** : si un joueur perd la connexion ou quitte en pleine manche, la partie est annulée/abandonnée pour tous. (Simplifie fortement l'architecture initiale — à revisiter en v2 si besoin.)

### 3.2 Scope v1 — strictement
Inclus : création/jonction de room, lobby avec choix d'équipe, partie complète jouable de bout en bout selon le règlement ci-dessus, animations Derba/Missa, écran de victoire.
Exclus explicitement de la v1 : chat (texte/vocal/emoji), historique/scoreboard persistant au-delà de la partie en cours, sons/musique d'ambiance élaborés, comptes utilisateurs, statistiques, classements, mode solo, mode local.

### 3.3 Direction artistique
- Thème : marocain chaleureux — motifs zellige, tons bois, palette rouge/vert/or, ambiance "café marocain".
- Cartes : jeu espagnol stylisé dans cette identité visuelle.
- À affiner en phase design dédiée avec maquettes concrètes avant implémentation UI.

### 3.4 Timer de tour
- Chaque joueur dispose de **10 secondes** pour jouer. Passé ce délai, le serveur joue d'office **la carte la plus à gauche** de sa main (capture obligatoire appliquée normalement).
- Compte à rebours visible par tous (anneau autour de l'avatar du joueur courant, barre au-dessus de la main pour soi).

### 3.5 Animations (Derba / Missa)
- **Bloquantes courtes (1-2s max)** : chaque déclenchement marque une pause volontaire pour créer l'impact, sans casser le rythme global.
- **Derba** : escalade visuelle sur les 3 paliers.
  - Palier 1 (1 pt) : effet léger, flash/glow discret sur les cartes concernées.
  - Palier 2 (5 pts, surenchère) : effet plus marqué (secousse, particules), doit se sentir comme une intensification nette.
  - Palier 3 (10 pts, surenchère max) : effet fort, quasi plein écran, moment fort de la partie.
  - Direction exacte à valider via maquettes/prototypes en phase design (à faire).
- **Missa** : effet discret mais satisfaisant sur la table qui se vide — pas de célébration extravagante, priorité à la clarté et à la sensation de "clean sweep".

---

## 4. Stack technique (validée)

- **Frontend mobile** : Flutter (Dart), cross-platform iOS + Android, un seul codebase. Choisi pour la richesse des animations custom possibles (Derba/Missa) et la bonne compatibilité avec Fable 5 pour la génération d'UI mobile.
- **Backend temps réel** : serveur WebSocket pur (Node.js/TypeScript, package `ws`) avec protocole JSON maison. Serveur **autoritaire** : toute la logique de jeu (règles, calcul des points, validation des coups) tourne côté serveur, le client Flutter ne fait qu'afficher l'état reçu et envoyer des intentions d'action. Nécessaire vu l'absence de comptes pour dissuader la triche côté client.
  - **Note de pivot (2026-07-11)** : Colyseus avait été validé initialement, mais il n'existe **aucun client Colyseus pour Dart/Flutter** (vérifié sur pub.dev — le protocole binaire 0.17 n'a pas de client communautaire vivant). Remplacé par WebSocket + JSON : plus simple, mieux adapté à un jeu tour-par-tour à état minuscule, et la logique de règles (`server/src/game/`) n'a pas changé d'une ligne.
- Codes de room : 5 caractères, alphabet sans ambiguïtés (pas de 0/O/1/I/L). Room détruite quand vide ou partie abandonnée.
- Hébergement du serveur : à définir avant déploiement (pas bloquant en local).

---

## 5. Historique des décisions

- 2026-07-11 : recueil de besoin initial complet (règles clarifiées, scope v1 figé, style visuel marocain choisi, pas d'auth/compte, pas de reconnexion en v1). Document créé.
- 2026-07-11 : stack validée (Flutter + Colyseus), scaffolding, moteur de règles testé (29 tests).
- 2026-07-11 : pivot backend Colyseus → WebSocket pur + JSON (pas de client Dart pour Colyseus). Fin de partie immédiate à 41 pts implémentée (vérification après chaque attribution de points, pas seulement en fin de manche). App Flutter v1 complète : accueil, lobby, table de jeu, animations Derba (3 paliers)/Missa, victoire. E2E validé : 4 clients Flutter réels jouent une partie complète contre le serveur.
- 2026-07-12 (bis) : deuxième passe de feedback. Pastille d'annonce : révèle désormais RONDA vs TRINGA (pas la valeur). Timer de tour de 10 s avec auto-jeu de la carte la plus à gauche (section 3.4). Animations de dernière capture (Roi = célébration, As = déception). Police display « Lilita One » (OFL), tout le texte en majuscules. Direction artistique : assets nano-banana-2 (cartes, fonds, dos) + UI « chunky » façon Caveboy Escape.
- 2026-07-12 : premier test utilisateur. Trois corrections de règles : (1) **capture obligatoire sur jumelle** — interdit de poser une carte à côté d'une carte de même valeur (clarifié avec l'utilisateur) ; (2) la **suite ascendante** se lit sur les valeurs présentes sur la table, pas sur l'ordre de pose (bug : un 4 laissait le 5 et le 6) ; (3) la **surenchère de Derba** était injouable (la réponse tombait sur table vide et cassait la chaîne) — corrigée, et décision utilisateur : le surenchérisseur emporte tout le paquet de la chaîne (butin). Une Derba exige la carte *juste* posée, pas une carte ancienne. Le choix capturer/poser disparaît du protocole et de l'UI (le serveur capture d'office).
