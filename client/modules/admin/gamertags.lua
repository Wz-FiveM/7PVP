---Gamertags admin : ID, nom et barre de vie au-dessus de la tête des joueurs à portée.
---Affichés seulement chez l'admin qui a activé l'option, jamais au lobby ni dans le créateur.
---@class GamertagsModule
local Gamertags = PVP.define('Gamertags')
local State = PVP.use('State')

Gamertags.active = false
Gamertags.running = false -- boucle en cours (couper puis remettre l'option ne doit pas en lancer une deuxième)
Gamertags.tags = {} -- joueur -> { id, ped }

-- Composants des gamertags du jeu
Gamertags.COMPONENT_NAME = 0
Gamertags.COMPONENT_HEALTH = 2

Gamertags.REFRESH_MS = 500

function Gamertags.init()
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then Gamertags.clear() end
    end)
end

---@param active boolean
function Gamertags.set(active)
    Gamertags.active = active
    if not active then return Gamertags.clear() end
    if not Gamertags.running then
        Gamertags.running = true
        CreateThread(Gamertags.loop)
    end
end

function Gamertags.loop()
    while Gamertags.active do
        if State.mode then Gamertags.refresh() else Gamertags.clear() end
        Wait(Gamertags.REFRESH_MS)
    end
    Gamertags.running = false
end

---Crée les gamertags des joueurs à portée et retire ceux qui n'y sont plus.
function Gamertags.refresh()
    local me = PlayerId()
    local coords = GetEntityCoords(PlayerPedId())
    local seen = {}

    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if player ~= me and ped ~= 0 and #(GetEntityCoords(ped) - coords) <= Config.Admin.GamertagDistance then
            seen[player] = true
            Gamertags.show(player, ped)
        end
    end

    for player in pairs(Gamertags.tags) do
        if not seen[player] then Gamertags.remove(player) end
    end
end

---@param player number
---@param ped number
function Gamertags.show(player, ped)
    local tag = Gamertags.tags[player]
    -- Le personnage change à la réapparition : le gamertag suit l'ancien, on le recrée
    if tag and (tag.ped ~= ped or not IsMpGamerTagActive(tag.id)) then
        Gamertags.remove(player)
        tag = nil
    end
    if tag then return end

    local label = ('[%d] %s'):format(GetPlayerServerId(player), GetPlayerName(player))
    local id = CreateFakeMpGamerTag(ped, label, false, false, '', 0)
    SetMpGamerTagVisibility(id, Gamertags.COMPONENT_NAME, true)
    SetMpGamerTagVisibility(id, Gamertags.COMPONENT_HEALTH, true)
    SetMpGamerTagAlpha(id, Gamertags.COMPONENT_HEALTH, 255)
    Gamertags.tags[player] = { id = id, ped = ped }
end

---@param player number
function Gamertags.remove(player)
    RemoveMpGamerTag(Gamertags.tags[player].id)
    Gamertags.tags[player] = nil
end

function Gamertags.clear()
    for player in pairs(Gamertags.tags) do Gamertags.remove(player) end
end
