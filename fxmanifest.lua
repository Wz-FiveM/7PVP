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
    'config/vehicles.lua',
    'config/shop.lua',
    'config/loot.lua',
    'config/crafting.lua',
    'config/contracts.lua',
    'config/control.lua',
    'config/freeroam.lua',
    'config/npcs.lua',
    'config/market.lua',
    'config/anticheat.lua',
    'config/zones.lua',
    'config/appearance.lua',
    'config/lobby.lua',
    'config/admin.lua',
    'shared/core/logger.lua',
    'shared/core/events.lua',
    'shared/modules/utils.lua',
    'shared/modules/progression.lua',
    'shared/modules/clock.lua',
    'shared/modules/safe_npcs.lua',
    'shared/modules/items.lua',
    'shared/modules/zones.lua',
    'shared/modules/appearance.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/discord.lua', -- côté serveur uniquement
    'server/core/callback.lua',
    'server/modules/discord/discord_service.lua',
    'server/modules/database/player_repository.lua',
    'server/modules/inventory/inventory_object.lua',
    'server/modules/player/player_object.lua',
    'server/modules/player/player_service.lua',
    'server/modules/connection/connection_service.lua',
    'server/modules/spawn/spawn_service.lua',
    'server/modules/loot/loot_service.lua',
    'server/modules/combat/combat_service.lua',
    'server/modules/combat/combat_tag_service.lua',
    'server/modules/combat/bounty_service.lua',
    'server/modules/contracts/contract_service.lua',
    'server/modules/crafting/crafting_service.lua',
    'server/modules/market/market_repository.lua',
    'server/modules/market/market_service.lua',
    'server/modules/anticheat/ban_repository.lua',
    'server/modules/anticheat/anticheat_service.lua',
    'server/modules/group/group_service.lua',
    'server/modules/teleport/teleport_service.lua',
    'server/modules/vehicle/vehicle_service.lua',
    'server/modules/airdrop/airdrop_service.lua',
    'server/modules/control/control_service.lua',
    'server/modules/season/season_service.lua',
    'server/modules/clock/clock_service.lua',
    'server/modules/inventory/inventory_service.lua',
    'server/modules/world/world_service.lua',
    'server/modules/appearance/appearance_service.lua',
    'server/modules/modes/mode_registry.lua',
    'server/modules/modes/pvp_mode.lua',
    'server/modules/modes/freeroam_mode.lua',
    'server/modules/lobby/lobby_service.lua',
    'server/modules/chat/chat_service.lua',
    'server/modules/admin/admin_service.lua',
    'server/modules/pve/pve_zone.lua',
    'server/modules/pve/pve_service.lua',
    'server/modules/pve/horde_service.lua',
    'server/modules/shop/shop_service.lua',
    'server/modules/leaderboard/leaderboard_service.lua',
    'server/api/exports.lua',
    'server/main.lua',
}

client_scripts {
    'client/core/callback.lua',
    'client/modules/state/state.lua',
    'client/modules/nui/nui.lua',
    'client/modules/nui/help_notify.lua',
    'client/modules/anticheat/heartbeat.lua',
    'client/modules/dui/dui_labels.lua',
    'client/modules/ped/ped_utils.lua',
    'client/modules/ped/fall.lua',
    'client/modules/zone/zone.lua',
    'client/modules/world/world.lua',
    'client/modules/inventory/inventory.lua',
    'client/modules/inventory/loadout.lua',
    'client/modules/inventory/shortcuts.lua',
    'client/modules/effects/effects.lua',
    'client/modules/hud/hud.lua',
    'client/modules/appearance/appearance.lua',
    'client/modules/creator/creator.lua',
    'client/modules/lobby/lobby.lua',
    'client/modules/chat/chat.lua',
    'client/modules/admin/noclip.lua',
    'client/modules/admin/admin.lua',
    'client/modules/spawn/spawn.lua',
    'client/modules/death/death.lua',
    'client/modules/combat/hits.lua',
    'client/modules/combat/bounty.lua',
    'client/modules/group/group.lua',
    'client/modules/airdrop/airdrop.lua',
    'client/modules/control/control.lua',
    'client/modules/freeroam/freeroam.lua',
    'client/modules/interaction/interaction_menu.lua',
    'client/modules/npcs/npcs.lua',
    'client/modules/pause/pause.lua',
    'client/modules/teleport/teleport.lua',
    'client/modules/vehicle/vehicles.lua',
    'client/modules/loot/loot.lua',
    'client/modules/pve/pve.lua',
    'client/modules/pve/horde.lua',
    'client/modules/clock/clock.lua',
    'client/modules/dev/dev.lua',
    'client/api/exports.lua',
    'client/main.lua',
}

-- Interface React (web/), compilée avec `npm run build`
ui_page 'web/build/index.html'

-- Écran de chargement : reste affiché jusqu'au lobby / créateur
-- (ShutdownLoadingScreenNui dans client/modules/lobby, creator et spawn)
loadscreen 'web/build/loading.html'
loadscreen_manual_shutdown 'yes'

files {
    'web/build/index.html',
    'web/build/loading.html',
    'web/build/dui.html',
    'web/build/assets/*',
    'web/build/items/*',
    'web/build/brand/*',
}
