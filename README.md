# 7PVP

Gamemode PvP / PvE pour FiveM, 100 % custom (aucun framework). Seule dépendance : [oxmysql](https://github.com/overextended/oxmysql). Interface en React + TypeScript (Vite).

## Principe

- **Toute la map est en PvP libre**, sauf les **zones safe** (spawn + boutique, tir désactivé, invincibilité).
- Les **zones PvE** sont infestées de **zombies** sans arme qui réapparaissent : au contact, ils vomissent sur le joueur et lui infligent des dégâts (l'armure encaisse en premier). Le PvP y reste actif. Réglages : `Config.Zombie` (`config/main.lua`) et le bloc `npc` de chaque zone.
- **À la mort**, tout le contenu du **sac** tombe au sol dans un **sac de butin** que n'importe qui peut ramasser. Le **conteneur protégé** est conservé. Le joueur réapparaît en zone safe avec le kit de respawn.
- Les zombies tués ne lâchent pas de sac : leur **corps porte le butin** (argent + loot aléatoire selon la zone). On le fouille avec `E`, et le corps disparaît une fois vidé (ou après `Config.LootLifetime`).
- **Hitmarker et dégâts infligés** quand on touche un joueur ou un zombie : blanc (corps), bleu (armure), jaune (tête), orange (coup mortel). Les dégâts sont mesurés par le propriétaire de la victime et relayés par le serveur (`client/modules/combat/hits.lua`).
- **Statut « en combat »** (`Config.CombatTagDuration`, 20 s) dès qu'on touche ou qu'on est touché par un joueur. Se déconnecter pendant ce temps compte comme une mort : sac au sol, mort comptée, kill et récompense pour le dernier attaquant, « DÉCO » dans le killfeed. Le retour au lobby est bloqué pendant le combat.
- XP/niveau, kills, morts, zombies tués et inventaire sont sauvegardés en base.

## Fonctionnalités

| Fonctionnalité | En bref | Réglages |
| --- | --- | --- |
| **Coffre** | 3e conteneur (250 kg), conservé, utilisable seulement en zone safe. Son contenu n'est pas porté. | `Config.Containers.stash` (`config/items.lua`) |
| **Groupes** | Jusqu'à 4 joueurs en PvP : pas de tir allié, coéquipiers en bleu sur la minimap et dans le HUD. Menu F2 > Groupe ou `/inviter ID`, `/accepter`, `/refuser`, `/quittergroupe`. | `Config.Groups` |
| **Largages aériens** | Une caisse tombe en parachute toutes les 20 min (2 joueurs PvP minimum), s'ouvre 60 s après l'atterrissage et se fouille avec `E`. | `Config.Airdrops`, table `airdrop` (`config/loot.lua`) |
| **Menu pause** | Échap / P : carte, paramètres GTA, menu F2, commandes, retour au lobby, quitter. | — |
| **Récap de mort** | Tueur, arme, distance, dégâts échangés et vie restante du tueur ; la caméra suit le tueur jusqu'à la réapparition. | — |
| **Séries et primes** | Dès 5 kills sans mourir, la tête du joueur est mise à prix (repère rouge) ; son tueur encaisse la prime. | `Config.Bounty` |
| **Accessoires** | Silencieux, lunette, chargeur, lampe, poignée : clic droit sur une arme > Fixer / Retirer. Ils tombent avec l'arme. | `Config.Attachments` (`config/items.lua`) |
| **Jour / nuit** | Heure commune calculée depuis l'heure réelle. La nuit : plus de zombies, plus rapides, plus résistants, plus de butin. | `Config.Time`, `Config.Night` |
| **Zombies spéciaux** | Rôdeur, Coureur (rapide), Colosse (très résistant, ne tombe pas), Cracheur (vomit à 10 m). | `Config.ZombieTypes` |
| **Hordes** | Toutes les 30 min, une zone PvE occupée est envahie 5 min ; les survivants dans la zone sont récompensés. | `Config.Hordes` |
| **Fabrication** | Matériaux récupérés sur les zombies -> munitions, soins, accessoires (zone safe, niveau requis). | `config/crafting.lua` |
| **Contrats quotidiens** | 3 contrats par jour (les mêmes pour tous), récompense versée à l'objectif. | `config/contracts.lua` |
| **Déblocages par niveau** | Les armes et accessoires de la boutique demandent un niveau minimum. | `level` dans `config/shop.lua` |
| **Zones de contrôle** | Reste seul (ou avec ton groupe) dans le cercle pour capturer ; la zone rapporte de l'argent à ton camp. | `config/control.lua` |
| **Saisons** | Une par mois : classement de saison à part (onglets Saison / précédente / de tous les temps). L'inventaire, l'argent et l'XP sont gardés. | table `pvp_season_stats` |
| **Freeroam** | Bac à sable : armes et véhicules gratuits (F2), PvP désactivé par défaut (chacun l'active pour soi), réapparition sur place, aucune perte. | `config/freeroam.lua` |

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

## Contrôles

| Touche / commande | Action |
| --- | --- |
| `F2` | Menu : inventaire, groupe, fabrication, contrats, profil, top joueurs, boutique, aide (en Freeroam : armes et véhicules) |
| `Échap` / `P` | Menu pause |
| `1` à `7` | Raccourcis : sortir / ranger une arme, utiliser un soin |
| `E` | Ramasser un sac de butin / fouiller un corps de zombie ou un largage |
| `/inviter ID` | Inviter un joueur dans son groupe (`/accepter`, `/refuser`, `/quittergroupe`) |
| `T` | Chat du mode en cours (`/commande` pour exécuter une commande, ↑/↓ pour l'historique) |
| `/lobby` | Retour au lobby (depuis une zone safe en PvP) |
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

## Arborescence

```
7PVP/
├── fxmanifest.lua
├── config/                     Tout le réglage, sans code
│   ├── main.lua                Joueur, combat, économie, PvE, interface
│   ├── items.lua               Objets, conteneurs, raccourcis, kits
│   ├── shop.lua                Boutique
│   ├── loot.lua                Tables de butin des PNJ
│   └── zones.lua               Zones safe / PvE
├── shared/
│   ├── core/
│   │   ├── module.lua          Système de modules (PVP.define / PVP.use / PVP.boot)
│   │   ├── logger.lua
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

## Discord

- **Bot** (`D:\7PVP\bot`, hors de la ressource) : programme Node.js qui crée le serveur Discord de 7PVP (rôles, salons, permissions, règlement, webhooks), puis gère l'accès par le règlement, les rôles, les tickets, le statut du serveur en direct et les logs. Mise en place dans son `README.md`.
- **Logs du jeu** (`server/modules/discord/discord_service.lua`) : killfeed, connexions, actions du panneau admin et `setadmin`, kicks (salon sanctions) et chat sont envoyés par webhooks. Les URLs sont des convars serveur (`7pvp_discord_killfeed`, `_sanctions`, `_connexions`, `_admin`, `_chat`) générées par le bot dans `bot/data/webhooks.cfg`, chargé par `exec bot/data/webhooks.cfg` dans `server.cfg`. Sans convar, le salon est ignoré. Réglages : `config/discord.lua`.

## Ajouter une zone PvE

Ajoute une entrée dans `config/zones.lua` avec `type = 'pve'` et un bloc `npc` (modèles, armes, points de spawn, table de loot). Les coordonnées fournies sont approximatives : vérifie-les en jeu avec `/pvp_coords`.

## Sécurité

- L'inventaire et l'argent sont uniquement modifiés côté serveur.
- Le client ne peut que faire **baisser** ses munitions, jamais les augmenter.
- Les achats vérifient la position du joueur, le ramassage vérifie la distance au sac, les kills vérifient la distance au tueur.
