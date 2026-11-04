# Prompts ChatGPT des bannières CoD

Une bannière = un prompt. Les ids et les noms suivent `config/cod_player_cards.lua`.

**Après la génération** : recadre la bande centrale (de y = 358 à y = 665), puis exporte-la en **WebP 1200 × 240** sous le nom `<id>.webp`.

**Pour une série cohérente** : fais-les toutes dans la même conversation. Après la première, tu peux n'envoyer que « Même style et même composition, nouveau thème : … » suivi de la ligne Thème du prompt voulu.

**Côté code** : `bannerUrl` (web/src/components/cod/CodPlayerCard.tsx) ajoute toujours `.svg`. Il faut l'adapter avant d'utiliser des images .webp.

## 1. Acier brossé (`steel`, rang 1)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Plaque d'acier brossé gris foncé, fines rayures horizontales, rivets alignés en haut et en bas, un reflet de lumière en diagonale, trois chevrons orange peints à la main sur la droite
Couleur d'accent : orange

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 2. Camouflage forêt (`woodland`, rang 1)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Tissu de treillis militaire au camouflage forêt (taches vert olive, brun et noir) qui couvre toute la bande, légèrement froissé, lumière rasante venant de la droite, quelques feuilles de fougère au premier plan à droite
Couleur d'accent : vert mousse

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 3. Camouflage désert (`desert`, rang 1)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Tissu de treillis au camouflage désert (sable, ocre, brun clair) sur toute la bande, poussière en suspension, à droite une crête de dune sous un soleil brûlant
Couleur d'accent : ocre doré

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 4. Camouflage urbain (`digital`, rang 1)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Camouflage urbain numérique en petits pixels gris, noirs et blancs sur toute la bande ; à droite, les pixels se détachent et s'envolent comme des éclats
Couleur d'accent : bleu glacier

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 5. Carbone (`carbon`, rang 1)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Fibre de carbone tissée noire et brillante sur toute la bande, reflet satiné, un filet rouge façon voiture de course qui traverse la partie droite en diagonale
Couleur d'accent : rouge vif

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 6. Zone dangereuse (`hazard`, rang 2)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Bandes diagonales jaunes et noires de zone dangereuse peintes sur du métal rouillé et écaillé, un gyrophare allumé sur la droite, fumée légère
Couleur d'accent : jaune signalisation

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 7. Los Santos (`skyline`, rang 4)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Silhouette d'une grande ville côtière californienne au crépuscule : gratte-ciel, palmiers, collines, lumières des fenêtres qui s'allument, ciel violet et orange plus lumineux à droite
Couleur d'accent : orange rosé

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 8. Balayage radar (`radar`, rang 8)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Écran radar militaire vert phosphore vu de face : cercles concentriques, quadrillage, faisceau de balayage lumineux centré sur la droite, quelques points ennemis qui clignotent
Couleur d'accent : vert phosphore

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 9. Un million (`million`, rang 6)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Liasses de billets de banque verts sans aucune inscription et lingots empilés sur une table sombre, billets qui volent à droite, lumière de lampe chaude
Couleur d'accent : vert billet

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 10. Fournaise (`flames`, rang 11)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Mur de flammes intenses qui montent depuis le bas de la partie droite, braises et étincelles qui volent, chaleur qui déforme l'air, fond noir à gauche
Couleur d'accent : orange feu

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 11. Vision thermique (`thermal`, rang 14)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Vue en caméra thermique : silhouette anonyme d'un soldat qui vise, sur la droite, en blanc-jaune brûlant sur fond violet et bleu froid, léger bruit d'image
Couleur d'accent : jaune thermique

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 12. Camouflage arctique (`arctic`, rang 17)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Camouflage arctique blanc, gris clair et bleu pâle sur toute la bande, couche de givre, cristaux de glace et neige qui tombe en biais sur la droite
Couleur d'accent : bleu glace

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 13. Orage (`storm`, rang 20)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Ciel d'orage noir et bleu nuit, nuages lourds, un éclair puissant qui frappe sur la droite et illumine les nuages, pluie en biais
Couleur d'accent : bleu électrique

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 14. Ossuaire (`skulls`, rang 23)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Crânes humains empilés dans une crypte de pierre, éclairés par une lumière rouge venant de la droite, poussière et toiles d'araignée, ambiance macabre mais lisible
Couleur d'accent : rouge sombre

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 15. Circuit imprimé (`circuit`, rang 26)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Circuit imprimé vert très foncé vu de près, pistes cuivrées fines qui convergent vers une puce lumineuse sur la droite, impulsions de lumière qui parcourent les pistes
Couleur d'accent : cyan

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 16. Escadrille (`squadron`, rang 29)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Escadrille de quatre avions de chasse en formation serrée, vus en silhouette de profil, qui foncent vers la droite en laissant des traînées blanches dans un ciel d'orage
Couleur d'accent : blanc acier et bleu

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 17. Lunette de tir (`scope`, rang 32)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Vue à travers une lunette de tireur d'élite : cercle noir de la lunette, fin réticule, cible lointaine floue sur la droite dans un paysage de ruines, reflet sur la lentille
Couleur d'accent : rouge réticule

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 18. Bain de sang (`blood`, rang 36)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Grandes éclaboussures et coulures de sang rouge vif sur une plaque de métal sombre et rayée, gouttes qui tombent sur la droite
Couleur d'accent : rouge sang

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 19. Soleil couchant (`chopper`, rang 40)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Hélicoptère de combat en silhouette noire sur la droite, devant un énorme soleil couchant orange au-dessus d'une ville en ruines, poussière dans l'air
Couleur d'accent : orange couchant

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 20. Champignon (`nuke`, rang 45)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Énorme champignon atomique lointain sur la droite, au-dessus d'un désert, onde de choc qui soulève la poussière, ciel rouge et orange qui brûle
Couleur d'accent : orange atomique

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 21. Or massif (`gold`, rang 50)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Plaque d'or massif gravée de motifs géométriques militaires, reflets chauds et brillants, rayures et impacts de balles sur la droite
Couleur d'accent : or

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 22. Légende (`legend`, rang 55)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Silhouette anonyme d'un soldat seul, debout de dos sur un champ de bataille en ruines, sur la droite, drapeau sans motif déchiré qui flotte, lumière dorée intense derrière lui, cendres qui volent
Couleur d'accent : or et rouge

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 23. Prestige 1 (`prestige1`, prestige 1)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Bannière de prestige en bronze : fond en dégradé horizontal, sombre à gauche et métallique à droite ; sur la droite, de grandes ailes stylisées et des chevrons gravés en bronze, sobre, une seule paire d'ailes. Couleurs : #b87333 sur fond #2e1c10. Plus le prestige est haut, plus la bannière est riche : celle-ci est le niveau 1 sur 10, mais ce chiffre ne doit pas apparaître
Couleur d'accent : bronze

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 24. Prestige 2 (`prestige2`, prestige 2)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Bannière de prestige en argent : fond en dégradé horizontal, sombre à gauche et métallique à droite ; sur la droite, de grandes ailes stylisées et des chevrons gravés en argent, sobre, ailes un peu plus grandes. Couleurs : #aeb7c0 sur fond #23272c. Plus le prestige est haut, plus la bannière est riche : celle-ci est le niveau 2 sur 10, mais ce chiffre ne doit pas apparaître
Couleur d'accent : argent

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 25. Prestige 3 (`prestige3`, prestige 3)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Bannière de prestige en or : fond en dégradé horizontal, sombre à gauche et métallique à droite ; sur la droite, de grandes ailes stylisées et des chevrons gravés en or, ailes déployées, quelques rayons de lumière. Couleurs : #d9a227 sur fond #33260a. Plus le prestige est haut, plus la bannière est riche : celle-ci est le niveau 3 sur 10, mais ce chiffre ne doit pas apparaître
Couleur d'accent : or

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 26. Prestige 4 (`prestige4`, prestige 4)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Bannière de prestige en rubis : fond en dégradé horizontal, sombre à gauche et métallique à droite ; sur la droite, de grandes ailes stylisées et des chevrons gravés en rubis, cristaux de rubis taillés incrustés dans le métal. Couleurs : #d8353b sur fond #330d10. Plus le prestige est haut, plus la bannière est riche : celle-ci est le niveau 4 sur 10, mais ce chiffre ne doit pas apparaître
Couleur d'accent : rubis

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 27. Prestige 5 (`prestige5`, prestige 5)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Bannière de prestige en saphir : fond en dégradé horizontal, sombre à gauche et métallique à droite ; sur la droite, de grandes ailes stylisées et des chevrons gravés en saphir, cristaux de saphir et reflets bleus. Couleurs : #2f7fd6 sur fond #0c2138. Plus le prestige est haut, plus la bannière est riche : celle-ci est le niveau 5 sur 10, mais ce chiffre ne doit pas apparaître
Couleur d'accent : saphir

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 28. Prestige 6 (`prestige6`, prestige 6)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Bannière de prestige en améthyste : fond en dégradé horizontal, sombre à gauche et métallique à droite ; sur la droite, de grandes ailes stylisées et des chevrons gravés en améthyste, cristaux violets et halo mystique. Couleurs : #8a4fd8 sur fond #22103a. Plus le prestige est haut, plus la bannière est riche : celle-ci est le niveau 6 sur 10, mais ce chiffre ne doit pas apparaître
Couleur d'accent : améthyste

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 29. Prestige 7 (`prestige7`, prestige 7)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Bannière de prestige en émeraude : fond en dégradé horizontal, sombre à gauche et métallique à droite ; sur la droite, de grandes ailes stylisées et des chevrons gravés en émeraude, cristaux verts et particules lumineuses. Couleurs : #22ad78 sur fond #0a2d22. Plus le prestige est haut, plus la bannière est riche : celle-ci est le niveau 7 sur 10, mais ce chiffre ne doit pas apparaître
Couleur d'accent : émeraude

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 30. Prestige 8 (`prestige8`, prestige 8)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Bannière de prestige en braise : fond en dégradé horizontal, sombre à gauche et métallique à droite ; sur la droite, de grandes ailes stylisées et des chevrons gravés en braise, métal chauffé au rouge, braises et étincelles. Couleurs : #ec7a1c sur fond #361a06. Plus le prestige est haut, plus la bannière est riche : celle-ci est le niveau 8 sur 10, mais ce chiffre ne doit pas apparaître
Couleur d'accent : braise

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 31. Prestige 9 (`prestige9`, prestige 9)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Bannière de prestige en platine : fond en dégradé horizontal, sombre à gauche et métallique à droite ; sur la droite, de grandes ailes stylisées et des chevrons gravés en platine, métal blanc éclatant, éclats de lumière très nets. Couleurs : #cfd6dd sur fond #0a0b0d. Plus le prestige est haut, plus la bannière est riche : celle-ci est le niveau 9 sur 10, mais ce chiffre ne doit pas apparaître
Couleur d'accent : platine

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

## 32. Prestige 10 (`prestige10`, prestige 10)

```
Crée une image horizontale au format 1536 × 1024 (3:2).
Contenu UNIQUEMENT dans une bande horizontale centrée de 1536 × 307 pixels (ratio 5:1). Au-dessus et en dessous : noir uni, sans aucun détail. Cette bande sera recadrée pour devenir une bannière de carte de joueur d'un jeu de tir militaire.

Thème : Bannière de prestige en or sur rouge sombre : fond en dégradé horizontal, sombre à gauche et métallique à droite ; sur la droite, de grandes ailes stylisées et des chevrons gravés en or sur rouge sombre, la plus impressionnante : grandes ailes d'or, flammes, couronne de rayons, cendres dorées. Couleurs : #f2b90f sur fond #4a0b0b. Plus le prestige est haut, plus la bannière est riche : celle-ci est le niveau 10 sur 10, mais ce chiffre ne doit pas apparaître
Couleur d'accent : or sur rouge sombre

Composition :
- Le tiers gauche de la bande reste sombre, peu chargé et peu contrasté : un emblème et un pseudo blanc y seront posés par-dessus.
- Le sujet principal, les détails et la lumière forte sont dans les deux tiers droits.
- L'essentiel reste au milieu de la hauteur de la bande, qui peut être rognée en haut et en bas.
- Lisible en petit (environ 370 × 74 pixels à l'écran) : formes franches, silhouettes nettes, pas de détails minuscules.

Style : illustration de jeu vidéo militaire moderne, rendu net et peint, éclairage cinématographique, contraste fort, palette sombre et désaturée avec une seule couleur d'accent vive, grain léger et texture usée.

Interdits : aucun texte, aucune lettre, aucun chiffre, aucun logo, aucune marque, aucun personnage reconnaissable, aucun cadre ni bordure, aucun filigrane.
```

