# 7PVP

Gamemode PvP / PvE pour FiveM, 100 % custom (aucun framework). Seule dépendance : [oxmysql](https://github.com/overextended/oxmysql). Interface en React + TypeScript (Vite).

## Principe

- **Toute la map est en PvP libre**, sauf les **zones safe** (spawn + boutique, tir désactivé, invincibilité).
- Les **zones PvE** contiennent des PNJ hostiles qui réapparaissent. Le PvP y reste actif.
- **À la mort**, tout le contenu du **sac** tombe au sol dans un **sac de butin** que n'importe qui peut ramasser. Le **conteneur protégé** est conservé. Le joueur réapparaît en zone safe avec le kit de respawn.
- Les PNJ tués lâchent aussi un sac (argent + loot aléatoire selon la zone).
- XP/niveau, kills, morts, PNJ tués et inventaire sont sauvegardés en base.

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
| `F2` | Menu : inventaire, profil, top joueurs, boutique (en zone safe), aide |
| `1` à `7` | Raccourcis : sortir / ranger une arme, utiliser un soin |
| `E` | Ramasser un sac de butin |
| `T` | Chat du mode en cours (`/commande` pour exécuter une commande, ↑/↓ pour l'historique) |
| `/lobby` | Retour au lobby (depuis une zone safe en PvP) |
| `/pvp_coords` | Affiche ta position en `vector4(...)` pour configurer les zones |

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

## Ajouter une zone PvE

Ajoute une entrée dans `config/zones.lua` avec `type = 'pve'` et un bloc `npc` (modèles, armes, points de spawn, table de loot). Les coordonnées fournies sont approximatives : vérifie-les en jeu avec `/pvp_coords`.

## Sécurité

- L'inventaire et l'argent sont uniquement modifiés côté serveur.
- Le client ne peut que faire **baisser** ses munitions, jamais les augmenter.
- Les achats vérifient la position du joueur, le ramassage vérifie la distance au sac, les kills vérifient la distance au tueur.
