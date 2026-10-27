fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name '7PVP'
description 'Gamemode PvP / PvE 100% custom'
version '0.2.0'

dependency 'oxmysql'

-- L'ordre des fichiers définit l'ordre d'appel des Module.init()
shared_scripts {
    'shared/core/module.lua',
    'config/main.lua',
    'config/items.lua',
    'config/shop.lua',
    'config/loot.lua',
    'config/zones.lua',
    'config/appearance.lua',
    'shared/core/logger.lua',
    'shared/core/events.lua',
    'shared/modules/utils.lua',
    'shared/modules/progression.lua',
    'shared/modules/items.lua',
    'shared/modules/zones.lua',
    'shared/modules/appearance.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core/callback.lua',
    'server/modules/database/player_repository.lua',
    'server/modules/inventory/inventory_object.lua',
    'server/modules/player/player_object.lua',
    'server/modules/player/player_service.lua',
    'server/modules/spawn/spawn_service.lua',
    'server/modules/loot/loot_service.lua',
    'server/modules/combat/combat_service.lua',
    'server/modules/inventory/inventory_service.lua',
    'server/modules/appearance/appearance_service.lua',
    'server/modules/pve/pve_zone.lua',
    'server/modules/pve/pve_service.lua',
    'server/modules/shop/shop_service.lua',
    'server/modules/leaderboard/leaderboard_service.lua',
    'server/api/exports.lua',
    'server/main.lua',
}

client_scripts {
    'client/core/callback.lua',
    'client/modules/state/state.lua',
    'client/modules/nui/nui.lua',
    'client/modules/ped/ped_utils.lua',
    'client/modules/zone/zone.lua',
    'client/modules/inventory/inventory.lua',
    'client/modules/inventory/loadout.lua',
    'client/modules/inventory/shortcuts.lua',
    'client/modules/hud/hud.lua',
    'client/modules/appearance/appearance.lua',
    'client/modules/creator/creator.lua',
    'client/modules/spawn/spawn.lua',
    'client/modules/death/death.lua',
    'client/modules/loot/loot.lua',
    'client/modules/pve/pve.lua',
    'client/modules/dev/dev.lua',
    'client/api/exports.lua',
    'client/main.lua',
}

-- Interface React (web/), compilée avec `npm run build`
ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/assets/*',
    'web/build/items/*',
}
