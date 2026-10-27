---Mode Freeroam : à construire. Il est déjà enregistré pour apparaître dans le lobby ;
---passe `enabled = true` dans config/lobby.lua quand il sera prêt.
---@class FreeroamModeModule
local FreeroamMode = PVP.define('FreeroamMode')
local ModeRegistry = PVP.use('ModeRegistry')

FreeroamMode.ID = 'freeroam'

function FreeroamMode.init()
    ModeRegistry.register(FreeroamMode.ID, FreeroamMode)
end

---@param player PvpPlayer
function FreeroamMode.enter(player)
    player:notify('Le Freeroam arrive bientôt.', 'info')
end

---@param player PvpPlayer
function FreeroamMode.leave(player)
end
