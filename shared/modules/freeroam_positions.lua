---Emplacements de la zone safe du Freeroam déplaçables depuis le panneau admin (onglet « Freeroam ») :
---PNJ des modes de jeu et tableaux du classement de chaque mode. Partagé : le serveur vérifie
---la portée des PNJ, le client les crée et dessine les tableaux (voir FreeroamConfigService).
---@class FreeroamPositionsModule
local FreeroamPositions = PVP.define('FreeroamPositions')
local Zones = PVP.use('Zones')

FreeroamPositions.MODE = 'freeroam'
FreeroamPositions.BOARD_SUFFIX = '/board'

---@param npc table entrée de Config.SafeNpcs.npcs
---@return string identifiant stable du PNJ (zone / mode de jeu ou rôle)
function FreeroamPositions.npcKey(npc)
    return npc.zone .. '/' .. (npc.activity or npc.role)
end

---Emplacements modifiables, dans l'ordre du panneau.
---@return { key: string, label: string, coords: vector4 }[] coords.w = cap
function FreeroamPositions.list()
    local list = {}
    for _, npc in ipairs(Config.SafeNpcs.npcs) do
        local zone = Zones.byId(npc.zone)
        if zone and Zones.inMode(zone, FreeroamPositions.MODE) then
            local activity = npc.activity and Config.FreeroamActivities[npc.activity]
            local role = Config.SafeNpcs.roles[npc.role]
            list[#list + 1] = {
                key = FreeroamPositions.npcKey(npc),
                label = 'PNJ · ' .. (activity and activity.label or role and role.label or npc.role),
                coords = npc.coords,
            }
        end
    end
    for _, board in ipairs(Config.FreeroamBoards.boards) do
        local activity = Config.FreeroamActivities[board.activity]
        list[#list + 1] = {
            key = FreeroamPositions.boardKey(board.activity),
            label = 'Tableau du classement · ' .. (activity and activity.label or board.activity),
            coords = vector4(board.coords.x, board.coords.y, board.coords.z, board.heading),
        }
    end
    return list
end

---@param activity string clé de Config.FreeroamActivities
---@return string identifiant stable du tableau (« chase/board » : clé d'origine, déjà enregistrée en base)
function FreeroamPositions.boardKey(activity)
    return activity .. FreeroamPositions.BOARD_SUFFIX
end

---@param key string
---@param coords vector4 coords.w = cap
---@return boolean emplacement trouvé
function FreeroamPositions.set(key, coords)
    for _, board in ipairs(Config.FreeroamBoards.boards) do
        if FreeroamPositions.boardKey(board.activity) == key then
            board.coords = coords.xyz
            board.heading = coords.w
            return true
        end
    end
    for _, npc in ipairs(Config.SafeNpcs.npcs) do
        if FreeroamPositions.npcKey(npc) == key then
            npc.coords = coords
            return true
        end
    end
    return false
end
