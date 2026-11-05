---Décor des zones safe du PvP (config/safe_decor.lua) : un ymap par zone, dans stream/safe_decor/.
---Le jeu les charge comme les cartes de GTA ; ce module les active dans les modes prévus
---(RequestIpl) et les retire dans les autres (RemoveIpl), dès que le mode change.
---@class SafeDecorModule
local SafeDecor = PVP.define('SafeDecor')
local State = PVP.use('State')

SafeDecor.LOOP_INTERVAL = 1000

---@type boolean|nil état appliqué (nil : rien appliqué encore)
SafeDecor.applied = nil

function SafeDecor.init()
    -- /pvp_decor : écrit dans F8 l'état de chaque ymap du décor
    RegisterCommand('pvp_decor', SafeDecor.print, false)
    CreateThread(SafeDecor.loop)
end

---@return boolean le décor doit être chargé dans le mode actuel
function SafeDecor.wanted()
    local config = Config.SafeDecor
    return config.enabled == true and State.mode ~= nil and config.modes[State.mode] == true
end

---@param active boolean
function SafeDecor.apply(active)
    for _, name in pairs(Config.SafeDecor.ymaps) do
        if active then RequestIpl(name) else RemoveIpl(name) end
    end
    SafeDecor.applied = active
end

function SafeDecor.loop()
    while true do
        local wanted = SafeDecor.wanted()
        if SafeDecor.applied ~= wanted then SafeDecor.apply(wanted) end
        Wait(SafeDecor.LOOP_INTERVAL)
    end
end

function SafeDecor.print()
    print(('[7PVP] Décor des zones safe : %s (mode %s)'):format(SafeDecor.wanted() and 'attendu' or 'retiré', tostring(State.mode)))
    for zoneId, name in pairs(Config.SafeDecor.ymaps) do
        print(('  - %s : %s %s'):format(zoneId, name, IsIplActive(name) and 'chargé' or 'non chargé'))
    end
end
