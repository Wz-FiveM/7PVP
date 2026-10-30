# 7PVP

Gamemode PvP / PvE pour FiveM, 100 % custom (aucun framework). Seule dépendance : [oxmysql](https://github.com/overextended/oxmysql). Interface en React + TypeScript (Vite).

## Principe

- **Toute la map est en PvP libre**, sauf les **zones safe** (spawn + boutique, tir désactivé, invincibilité).
- Les **zones PvE** sont infestées de **zombies** sans arme qui réapparaissent : au contact, ils vomissent sur le joueur et lui infligent des dégâts (l'armure encaisse en premier). En y entrant, le joueur passe dans un **monde zombies** à part (bucket de routage), partagé avec les autres joueurs qui farment, **sans PvP** ; il revient au monde PvP en sortant de la zone. Le butin n'est visible et ramassable que dans le monde où il est tombé (`Config.PveWorld`). Réglages : `Config.Zombie` (`config/main.lua`) et le bloc `npc` de chaque zone.
- **À la mort**, tout le contenu du **sac** tombe au sol dans un **sac de butin** que n'importe qui peut ramasser. Le **conteneur protégé** est conservé. Le joueur réapparaît en zone safe avec le kit de respawn.
- Les zombies tués ne lâchent pas de sac : leur **corps porte le butin** (argent + loot aléatoire selon la zone). On le fouille avec `E`, et le corps disparaît une fois vidé (ou après `Config.LootLifetime`).
- **Hitmarker et dégâts infligés** quand on touche un joueur ou un zombie : blanc (corps), bleu (armure), jaune (tête), orange (coup mortel). Les dégâts sont mesurés par le propriétaire de la victime et relayés par le serveur (`client/modules/combat/hits.lua`).
- **Statut « en combat »** (`Config.CombatTagDuration`, 20 s) dès qu'on touche ou qu'on est touché par un joueur. Se déconnecter pendant ce temps compte comme une mort : sac au sol, mort comptée, kill et récompense pour le dernier attaquant, « DÉCO » dans le killfeed. Le retour au lobby est bloqué pendant le combat.
- XP/niveau, kills, morts, zombies tués et inventaire sont sauvegardés en base.

## Fonctionnalités

| Fonctionnalité | En bref | Réglages |
| --- | --- | --- |
| **PNJ de la zone safe** | Banquier (coffre), armurier (boutique), tailleur (tenue), artisan (fabrication), recruteur (contrats), commissaire-priseur (place de marché) : repère sur la carte, `E` pour leur parler. Coffre, achats, fabrication et tenue ne se font qu'à côté du PNJ (vérifié par le serveur). | `config/npcs.lua` |
| **Place de marché** | Auprès du commissaire-priseur : mettre en vente des objets portés (ils quittent l'inventaire), acheter ceux des autres, retirer ses annonces. L'argent des ventes (moins 5 % de taxe) est à récupérer chez lui, même si on était déconnecté. Annonces gardées en base. | `config/market.lua` |
| **Coffres** | Conteneurs conservés, utilisables seulement auprès du banquier, en onglets (Coffre 1, 2, 3). Le coffre 1 est offert, les suivants s'achètent une fois pour toutes chez le banquier avec l'argent porté. Leur contenu n'est pas porté. | `Config.Containers.stash*` (`config/items.lua`) |
| **Équipes** | Jusqu'à 4 joueurs en PvP : pas de tir allié, vie et armure de chaque coéquipier à gauche de l'écran, repères bleus sur la carte à toute distance (positions envoyées par le serveur). Menu (Verr. Maj) > Équipe ou `/inviter ID`, `/accepter`, `/refuser`, `/quittergroupe`. | `Config.Groups` |
| **Échanges** | `/trade ID` (ou menu d'interaction > Proposer un échange) : en PvP, à moins de 5 m, hors combat. L'inventaire s'ouvre avec les deux offres à droite ; on y glisse ses objets (argent compris), chacun passe « Prêt » puis les deux confirment. Toute modification retire les « Prêt » ; tout est revérifié et appliqué d'un coup par le serveur. Fermer le menu, s'éloigner, mourir ou entrer en combat annule. | `Config.Trade` |
| **Largages aériens** | Une caisse tombe en parachute toutes les 20 min (2 joueurs PvP minimum), s'ouvre 60 s après l'atterrissage et se fouille avec `E`. | `Config.Airdrops`, table `airdrop` (`config/loot.lua`) |
| **Menu pause** | Échap / P : carte, paramètres GTA, inventaire, commandes, retour au lobby, quitter. | — |
| **Récap de mort** | Tueur, arme, distance, dégâts échangés et vie restante du tueur ; la caméra suit le tueur jusqu'à la réapparition. | — |
| **Séries et primes** | Dès 5 kills sans mourir, la tête du joueur est mise à prix (repère rouge) ; son tueur encaisse la prime. | `Config.Bounty` |
| **Accessoires** | Silencieux, lunette, chargeur, lampe, poignée : clic droit sur une arme > Fixer / Retirer. Ils tombent avec l'arme. | `Config.Attachments` (`config/items.lua`) |
| **Jour / nuit** | Heure commune calculée depuis l'heure réelle. La nuit : plus de zombies, plus rapides, plus résistants, plus de butin. | `Config.Time`, `Config.Night` |
| **Zombies spéciaux** | Rôdeur, Coureur (rapide), Colosse (très résistant, ne tombe pas), Cracheur (vomit à 10 m), Casqué (casque blindé : la tête ne tue pas d'un coup avant que le casque saute), Bonbonne (bouteille de gaz dans le dos qui explose à sa mort), SWAT (gilet pare-balles), Anti-émeute (bouclier qui arrête les balles), Toxique (masque à gaz, nuage toxique à sa mort ; l'Antizin protège). Les équipés sont plus fréquents la nuit. | `Config.ZombieTypes`, `Config.ZombieGear` |
| **Hordes** | Toutes les 30 min, une zone PvE occupée est envahie 5 min ; les survivants dans la zone sont récompensés. | `Config.Hordes` |
| **Fabrication** | Matériaux récupérés sur les zombies -> munitions, soins, accessoires (zone safe, niveau requis). | `config/crafting.lua` |
| **Contrats quotidiens** | 3 contrats par jour (les mêmes pour tous), récompense versée à l'objectif. | `config/contracts.lua` |
| **Déblocages par niveau** | Les armes et accessoires de la boutique demandent un niveau minimum. | `level` dans `config/shop.lua` |
| **Zones de contrôle** | Reste seul (ou avec ton groupe) dans le cercle pour capturer ; la zone rapporte de l'argent à ton camp. | `config/control.lua` |
| **Saisons** | Une par mois : classement de saison à part (onglets Saison / précédente / de tous les temps). L'inventaire, l'argent et l'XP sont gardés. | table `pvp_season_stats` |
| **Freeroam** | Bac à sable : armes et véhicules gratuits (Verr. Maj), PvP désactivé par défaut (chacun l'active pour soi), réapparition sur place, aucune perte. Modes de jeu (CVC, course poursuite, 1VS1) auprès des PNJ de la zone safe, chacun avec son classement ELO affiché sur un écran à côté de son PNJ. | `config/freeroam.lua`, `config/boards.lua` |

Le panneau admin (F10 > Serveur) peut lancer un largage sur soi et une horde dans la zone PvE la plus proche, pour tester.

## Inventaire

- **Tout est objet** : armes (x1), munitions par calibre (9mm, 5.56mm…), soins, argent. Catalogue dans `config/items.lua`.
- **Deux conteneurs avec limite de poids** (`Config.Containers`) : le **sac** (perdu à la mort) et le **conteneur protégé** (conservé).
- **Munitions partagées** : toutes les armes d'un même calibre puisent dans le même objet de munitions. Les balles tirées sont décomptées de l'inventaire (le sac d'abord, puis le conteneur protégé).
- **Raccourcis** : 7 emplacements (touches `1` à `7`) pour sortir une arme ou utiliser un soin.
- **Interface** : glisser-déposer entre conteneurs et vers les raccourcis, double-clic pour utiliser, clic droit pour déplacer ou jeter (avec choix de la quantité).
- **Images** : dépose `web/public/items/<nom_objet>.png` (ex : `weapon_pistol.png`) puis relance `npm run build`. Sans image, une icône selon le type est affichée.

## Installation

1. Installe et démarre `oxmysql` (avec `mysql_connection_string` dans le `server.cfg`).
2. Compile l'interface :
   ```bash
   cd web
   npm install
   npm run build
   ```
3. Dans le `server.cfg` :
   ```cfg
   ensure oxmysql
   ensure 7PVP
   ```
   Retire `basic-gamemode` et `mapmanager` : 7PVP gère lui-même le spawn. Si `spawnmanager` tourne, son auto-spawn est désactivé automatiquement.
4. **OneSync doit être activé** : les PNJ et les armes sont gérés côté serveur.
5. La table `pvp_players` est créée automatiquement au démarrage (voir `sql/7pvp.sql`).

## Mise à jour du VPS

Sur le VPS (hôte SSH `seven`), la resource `/opt/7pvp/server-data/resources/7PVP` est un clone de ce dépôt GitHub, branche `main`. Le serveur tourne avec le service systemd `7pvp`, txAdmin sur le port 40121.

Pour mettre à jour : committer, puis `deploy.bat`. Il pousse les commits sur GitHub et lance `tools/update.sh` sur le VPS, qui fait le `git pull` et recompile l'interface (Node 20 installé sur le VPS) seulement si `web/` a changé. Les fichiers non commités ne partent pas.

| Commande | Effet |
| --- | --- |
| `.\deploy.bat` | Pousse les commits, met à jour le VPS, sans redémarrer |
| `.\deploy.bat -Redemarrer` | Pareil, puis redémarre le serveur et attend qu'il réponde (demande confirmation si des joueurs sont connectés, sauf avec `-Force`) |
| `.\deploy.bat -Apercu` | Liste les commits qui arriveraient, sans rien modifier |
| `.\deploy.bat -Restaurer` | Revient à la version d'avant la dernière mise à jour (relancer remonte encore) ; la mise à jour suivante reprend GitHub |

Directement sur le VPS : `bash /opt/7pvp/server-data/resources/7PVP/tools/update.sh` (mêmes options : `--apercu`, `--restaurer`). Ne pas modifier de fichiers sur le VPS : la mise à jour refuse de les écraser. Le `server.cfg` est hors du dépôt et n'est jamais touché. Réglages (hôte, chemins) en haut de `tools/deploy-vps.ps1`.

## Contrôles

| Touche / commande | Action |
| --- | --- |
| `Verr. Maj` | Menu : inventaire, groupe, profil, top joueurs, boutique, aide (en Freeroam : armes et véhicules). Le coffre, la fabrication et les contrats s'ouvrent en parlant aux PNJ de la zone safe |
| `Échap` / `P` | Menu pause |
| `Alt` (maintenu) | Menu d'interaction : curseur, la cible survolée est entourée, clic pour ouvrir son menu. Toi (ID, niveau, équipe), un joueur (inviter, exclure, prime, échanger), un butin (fouiller), un PNJ (parler), un véhicule (monter) |
| `1` à `7` | Raccourcis : sortir / ranger une arme, utiliser un soin |
| `E` | Ramasser un sac de butin / fouiller un corps de zombie ou un largage |
| `/inviter ID` | Inviter un joueur dans son groupe (`/accepter`, `/refuser`, `/quittergroupe`) |
| `/trade ID` | Proposer un échange (sans ID : le joueur le plus proche) ; `/trade accepter`, `/trade refuser`, `/trade annuler` |
| `T` | Chat du mode en cours (`/commande` pour exécuter une commande, ↑/↓ pour l'historique) |
| `/lobby` | Retour au lobby (depuis une zone safe en PvP) |
| `/langue en` | Change la langue (`/language` marche aussi ; sans code : liste des langues). Aussi dans le menu pause et le lobby |
| `F10` / `F11` | Admins : panneau d'administration / noclip |
| `/tpm` | Admins : téléportation au marqueur de la carte |
| `/pvp_coords` | Affiche ta position en `vector4(...)` pour configurer les zones |

## Administration

Dans la console du serveur :

```
setadmin <id | license:xxxx>      rend admin (enregistré en base, effet immédiat, gardé au redémarrage)
removeadmin <id | license:xxxx>   retire les droits
admins                            liste les admins enregistrés
```

Le statut est stocké dans la colonne `is_admin` de `pvp_players` : aucune ligne `server.cfg` n'est nécessaire.
L'ACE `7pvp.admin` (`add_ace group.admin 7pvp.admin allow`) donne aussi les droits, en plus de la base.

```
ban <id | license:xxxx> <jours> <raison>   bannit (0 jour = définitif), même hors ligne
unban <license:xxxx>                        lève le ban
bans                                        liste les bans en cours
```

### Points boutique (Tebex)

Monnaie premium achetée sur la boutique Tebex, dépensée en jeu (caisses : bouton « PB », achetée et ouverte aussitôt, partout hors combat). Solde gardé en base à part de l'inventaire (`pvp_shop_points`, jamais perdu à la mort ni échangeable), chaque mouvement est journalisé (`pvp_shop_points_log`) et chaque crédit/retrait par commande part dans le salon Discord admin. Réglages : `config/shop_points.lua` (nom, abréviation, lien de la boutique affiché dans le menu) ; prix en points : `points` dans `config/cases.lua`.

```
addpoints <id | license:xxxx> <montant> [référence]   crédite (même hors ligne) ; une référence déjà créditée est ignorée
removepoints <id | license:xxxx> <montant>            retire (le solde ne descend pas sous 0)
points <id | license:xxxx>                            affiche le solde
```

Sur Tebex, dans chaque paquet, ajouter la commande (avec « joueur en ligne requis ») :
`addpoints {sid} 1000 {transaction}` — et pour les remboursements / rétrofacturations : `removepoints {sid} 1000`.

## Anti-cheat

Tout est contrôlé par le serveur (`server/modules/anticheat/`, réglages dans `config/anticheat.lua`) ; les admins ne sont jamais contrôlés.

| Détection | Ce qui est vérifié | Sanction par défaut |
| --- | --- | --- |
| Arme non possédée | Touche faite en PvP avec une arme absente de l'inventaire (la touche est annulée) | Kick à la 3e alerte |
| Dégâts anormaux | Plus de 250 dégâts en une touche (touche annulée) | Kick à la 3e |
| Explosion interdite | Grenade, roquette, bombe collante… en PvP (explosion annulée) | Ban définitif à la 2e |
| Véhicule créé en PvP | Le mode n'en donne pas : véhicule apparu par un joueur (création annulée) | Kick à la 3e |
| Vie / armure | Au-dessus de 200 PV ou 100 d'armure | Kick à la 3e |
| Invincibilité | Joueur invincible hors zone safe | Journal |
| Téléportation | Plus de 60 m à plus de 120 m/s entre deux relevés (sauf réapparition, action d'admin) | Journal |
| Requêtes en rafale | Menus, touches ou ramassages envoyés en boucle (ignorés au-delà de la limite) | Kick à la 2e |
| Script client arrêté | Plus de signal du client depuis 90 s (« resource stopper ») | Kick |

Chaque alerte est écrite dans la console et dans le salon Discord « sanctions ». Les bans sont gardés dans la table `pvp_bans` et vérifiés à la connexion.

## Arborescence

```
7PVP/
├── fxmanifest.lua
├── config/                     Tout le réglage, sans code
│   ├── main.lua                Joueur, combat, économie, PvE, interface
│   ├── items.lua               Objets, conteneurs, raccourcis, kits
│   ├── shop.lua                Boutique
│   ├── loot.lua                Tables de butin des PNJ
│   ├── locale.lua              Langues disponibles
│   ├── cod.lua                 Mode Call of Duty : listes de jeu, armes, atouts, séries, rangs, cartes
│   ├── cod_player_cards.lua    Mode Call of Duty : bannières, emblèmes et tag des cartes de joueur
│   └── zones.lua               Zones safe / PvE
├── locales/                    Traductions (en.json, es.json... : texte français -> traduction)
├── tools/locales.js            Vérifie et fusionne les traductions
├── shared/
│   ├── core/
│   │   ├── module.lua          Système de modules (PVP.define / PVP.use / PVP.boot)
│   │   ├── logger.lua
│   │   ├── locale.lua          Traductions (Locale.t)
│   │   └── events.lua          Noms de tous les événements et callbacks
│   └── modules/                Utils, Progression, Zones, Items
├── server/
│   ├── core/callback.lua       Callbacks client -> serveur avec réponse
│   ├── modules/
│   │   ├── database/           PlayerRepository (SQL)
│   │   ├── player/             PlayerObject (classe) + PlayerService (cycle de vie)
│   │   ├── inventory/          InventoryObject (classe : conteneurs, poids, raccourcis)
│   │   │                       + InventoryService (utiliser, déplacer, jeter, raccourcis)
│   │   ├── spawn/              SpawnService
│   │   ├── combat/             CombatService (morts, récompenses, killfeed)
│   │   ├── loot/               LootService (sacs, tables de butin)
│   │   ├── pve/                PveZone (classe) + PveService
│   │   ├── shop/               ShopService
│   │   └── leaderboard/        LeaderboardService
│   ├── api/exports.lua         API publique serveur
│   └── main.lua                Démarrage
├── client/
│   ├── core/callback.lua       Callback.await(...)
│   ├── modules/                State, Nui, PedUtils, Zone, Spawn, Death, Loot, Pve, Dev
│   │   ├── inventory/          Inventory (soins, équiper), Loadout (armes + suivi des munitions), Shortcuts (touches 1-7)
│   │   └── hud/                Hud (santé, armure, arme en main -> interface)
│   ├── api/exports.lua         API publique client
│   └── main.lua                Démarrage
├── web/                        Interface React + TypeScript
│   └── src/
│       ├── api/                fetchNui + gameApi (toutes les requêtes vers Lua)
│       ├── store/              État global (reducer + context)
│       ├── hooks/              useNuiMessage, useCountdown
│       ├── i18n/               Traductions de l'interface (useT, t, formatNumber)
│       ├── styles/             Jetons de la D.A Frontline (global.css) + classes communes (ui.css)
│       ├── components/ui/      Panneau, jauge à segments, puce de zone, crochets de sélection, logo
│       ├── components/hud/     HUD en jeu : zone, statut, killfeed, santé/armure, raccourcis, munitions, mort
│       ├── components/menu/    Menu plein écran avec barre d'onglets
│       ├── components/inventory/ Tuiles, conteneurs, fiche objet, opérateur, glisser-déposer, raccourcis
│       ├── pages/              Inventaire, Profil, Top joueurs, Boutique, Aide (+ index.ts)
│       ├── types/              Types partagés et messages NUI
│       └── dev/                Panneau de dev, scénarios et données factices pour `npm run dev`
└── sql/7pvp.sql
```

## Système de modules

Il n'y a aucune fonction locale : chaque fichier déclare **un module** et toutes ses fonctions sont publiques sur ce module.

```lua
local MonService = PVP.define('MonService')    -- déclare le module de ce fichier
local PlayerService = PVP.use('PlayerService') -- dépendance (même si chargée plus tard)

function MonService.init()        -- appelé automatiquement au démarrage
    RegisterNetEvent(Events.server.xxx, function(...) MonService.onXxx(source, ...) end)
end

function MonService.onXxx(source, ...)
    local player = PlayerService.get(source)
end
```

- `PVP.define(nom)` : déclare le module du fichier (erreur s'il est déclaré deux fois).
- `PVP.use(nom)` : récupère un autre module. L'ordre de chargement des fichiers n'a donc pas d'importance.
- `PVP.boot()` : appelle `init()` sur chaque module, dans l'ordre du `fxmanifest.lua`. Il lève une erreur si un module est utilisé sans jamais être défini.
- Les **classes** (`PlayerObject`, `InventoryObject`, `PveZone`) sont des modules avec `__index` et un constructeur `new`.
- Les **noms d'événements** sont tous dans `shared/core/events.lua`. N'écris jamais un nom d'événement en dur ailleurs.

Pour ajouter un module : crée le fichier dans `server/modules/<domaine>/` ou `client/modules/<domaine>/`, puis ajoute-le dans `fxmanifest.lua` avant `main.lua`.

## Callbacks

Une requête client qui attend une réponse du serveur :

```lua
-- serveur
Callback.register(Events.callbacks.buy, ShopService.buy) -- handler(source, ...) -> résultat

-- client
local result = Callback.await(Events.callbacks.buy, index)
```

## API publique (exports)

Côté serveur :

```lua
exports['7PVP']:getPlayer(source)            -- données du joueur ou nil
exports['7PVP']:getMoney(source)             -- argent total (sac + conteneur protégé)
exports['7PVP']:addMoney(source, amount)      -- ajouté dans le sac
exports['7PVP']:removeMoney(source, amount)   -- false si pas assez d'argent
exports['7PVP']:addXp(source, amount)
exports['7PVP']:giveItem(source, 'weapon_pistol', 1)          -- renvoie la quantité ajoutée (limite de poids)
exports['7PVP']:giveItem(source, 'medkit', 2, 'protected')    -- directement dans le conteneur protégé
exports['7PVP']:removeItem(source, 'ammo_9mm', 24)
exports['7PVP']:getItemCount(source, 'ammo_9mm')
exports['7PVP']:getZone(source)               -- { id, label, type }
exports['7PVP']:isInSafeZone(source)
exports['7PVP']:dropLoot(coords, { weapon_pistol = 1, ammo_9mm = 24, money = 100 })
exports['7PVP']:getShopPoints(source)                                 -- solde de points boutique
exports['7PVP']:addShopPoints(source | 'license:xxxx', 500, 'raison', 'ref-unique')  -- 'ok' | 'duplicate' | 'invalid' | 'error'
exports['7PVP']:removeShopPoints(source, 500, 'raison')               -- false si le solde est insuffisant
```

Côté client :

```lua
exports['7PVP']:getPlayer()
exports['7PVP']:isDead()
exports['7PVP']:getZone()
exports['7PVP']:isInSafeZone()
exports['7PVP']:openMenu()
exports['7PVP']:closeMenu()
exports['7PVP']:notify('Texte', 'success')
-- Aide (touche + texte) dans le style de 7PVP, à appeler à chaque image tant qu'elle doit rester
-- affichée (elle disparaît seule ensuite) ; la touche par défaut est celle d'interaction (E)
exports['7PVP']:showHelpNotification('Ouvrir le coffre')
exports['7PVP']:showHelpNotification('Démarrer', 'G')
exports['7PVP']:hideHelpNotification()
```

## Interface (web/)

```bash
cd web
npm run dev     # développement dans le navigateur avec des données factices + panneau « DEV NUI »
npm run build   # compile dans web/build/ (chargé par FiveM)
```

- Lua -> React : `Nui.send(action, data)`. Les messages sont typés dans `src/types/nui.ts`.
- React -> Lua : `gameApi` (`src/api/gameApi.ts`), qui appelle les `RegisterNUICallback` de `client/modules/nui/nui.lua`.

### Écran de chargement

Deuxième page React (`web/loading.html`, code dans `src/loading/`), déclarée en `loadscreen` dans le fxmanifest. Il reste affiché jusqu'au lobby ou au créateur (`loadscreen_manual_shutdown`). Il montre la progression envoyée par FiveM, des astuces (`src/loading/tips.ts`) et le pseudo / nombre de joueurs transmis par le serveur à la connexion (`server/modules/connection`). En dev : `http://localhost:5173/loading.html` (progression simulée).

### Panneau « DEV NUI » (npm run dev)

En haut de l'écran, uniquement dans le navigateur (jamais en jeu) :

- **Écran** : lobby, créateur (création / édition), HUD PvP, menu (en zone safe ou non), écran de mort, chat ouvert. Le dernier écran choisi est rouvert au rechargement.
- **Événements** : messages de chat, notifications, killfeed, raccourcis, changement de zone, santé.
- Chaque bouton envoie de vrais messages NUI (`window.postMessage`), comme le Lua : on teste le même chemin qu'en jeu. Pour ajouter un écran ou un événement : `src/dev/devScenarios.ts`.
- `TAB` affiche les raccourcis et `T` ouvre le chat, comme en jeu.

### Direction artistique « Frontline »

- **Couleurs** (variables dans `src/styles/global.css`) : neutres Nuit `#0B0D0E`, Carbone `#14181A`, Acier `#1E2427`, Trait `#2E363A`, Brume `#8C969B`, Os `#E9ECE6`. Les couleurs de zone ne servent qu'à ça : **Abri** `#4CC9E0` (safe, conteneur protégé), **Toxine** `#B5F23D` (PvE), **Hazard** `#FF6B1A` (PvP, marque, actions).
- **Polices** : Chakra Petch (titres, majuscules), Barlow (texte), JetBrains Mono (chiffres, poids, touches). Elles sont embarquées dans le build : aucune connexion internet n'est nécessaire en jeu.
- **Formes** : panneaux pleins aux coins coupés à 45° (`.cut`, `.cut-s`), crochets de visée pour la sélection (`<Brackets />`), bandes d'alerte dans la couleur de la zone (`.stripes` + `.zone-safe|pve|pvp`), jauges à segments (`<SegmentBar />`).

## Langues

Le jeu est traduit en français (langue d'origine), anglais, espagnol, allemand, italien et portugais. Chaque joueur choisit sa langue dans le menu pause, en haut du lobby ou avec `/langue <code>` ; le choix est gardé sur son PC (KVP). À la première connexion, la langue de GTA V est reprise si elle est disponible (`Config.Locale`, `config/locale.lua`).

- **Le texte français sert de clé** : `locales/<langue>.json` associe chaque texte français à sa traduction. Un texte absent d'un fichier reste en français, rien ne casse.
- Lua : `Locale.t('Niveau %d atteint !', niveau)` (`shared/core/locale.lua`). Côté client, il renvoie le texte traduit. Côté serveur, il renvoie un message que le client traduit à la réception (`Nui.send`, `Callback.await`) : ne pas le concaténer, et garder le français brut pour les journaux et Discord.
- React : `const t = useT()` puis `t('Déployer')`, `t('Niveau {level}', { level })` (`web/src/i18n`). Les textes de la config (noms d'objets, zones...) se traduisent au rendu : `t(item.label)`.
- Ajouter une langue : une entrée dans `Config.Locale.languages`, un fichier `locales/<code>.json` (et son format de nombres dans `web/src/i18n/index.ts`).
- `node tools/locales.js check` liste les textes du code sans traduction (et les traductions dont les `%s` / `{x}` ne correspondent pas) ; `node tools/locales.js merge fichier.json` ajoute un lot de traductions `{ "texte fr": { "en": "...", "es": "..." } }`.

## Discord

- **Bot** (`D:\7PVP\bot`, hors de la ressource) : programme Node.js qui crée le serveur Discord de 7PVP (rôles, salons, permissions, règlement, webhooks), puis gère l'accès par le règlement, les rôles, les tickets, le statut du serveur en direct et les logs. Mise en place dans son `README.md`.
- **Logs du jeu** (`server/modules/discord/discord_service.lua`) : killfeed, connexions, actions du panneau admin et `setadmin`, kicks (salon sanctions) et chat sont envoyés par webhooks. Les URLs sont des convars serveur (`7pvp_discord_killfeed`, `_sanctions`, `_connexions`, `_admin`, `_chat`) générées par le bot dans `bot/data/webhooks.cfg`, chargé par `exec bot/data/webhooks.cfg` dans `server.cfg`. Sans convar, le salon est ignoré. Réglages : `config/discord.lua`.

## Ajouter une zone PvE

Ajoute une entrée dans `config/zones.lua` avec `type = 'pve'` et un bloc `npc` (modèles, armes, points de spawn, table de loot). Les coordonnées fournies sont approximatives : vérifie-les en jeu avec `/pvp_coords`.

## Sécurité

- L'inventaire et l'argent sont uniquement modifiés côté serveur.
- Le client ne peut que faire **baisser** ses munitions, jamais les augmenter.
- Les achats vérifient la position du joueur, le ramassage vérifie la distance au sac, les kills vérifient la distance au tueur.
