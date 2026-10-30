---Personnages des autres joueurs du salon, autour de celui du joueur dans le menu du mode.
---Chaque joueur reste seul dans son bucket : ce sont des copies locales, sans entité réseau,
---créées d'après la liste envoyée par le serveur (CodService.sendSquad).
---@class CodSquadModule
local CodSquad = PVP.define('CodSquad')
local Cod = PVP.use('Cod')
local Appearance = PVP.use('Appearance')
local AppearanceSchema = PVP.use('AppearanceSchema')
local PedUtils = PVP.use('PedUtils')

---@type { id: integer, appearance: table|nil, weapon: string }[] autres joueurs du salon
CodSquad.members = {}
---@type table<integer, { ped: integer, weapon: string }> server id -> personnage affiché
CodSquad.shown = {}

---@param members { id: integer, appearance: table|nil, weapon: string }[] joueurs du salon, lui compris
function CodSquad.setMembers(members)
    local self = GetPlayerServerId(PlayerId())
    CodSquad.members = {}
    for _, member in ipairs(members) do
        if member.id ~= self then CodSquad.members[#CodSquad.members + 1] = member end
    end
    -- Après l'ouverture du menu en cours, s'il y en a une
    Cod.exclusive(CodSquad.sync)
end

---Met les personnages à jour : le menu peut se fermer pendant le chargement d'un modèle.
function CodSquad.sync()
    local wanted = {}
    for index, member in ipairs(CodSquad.members) do
        if Config.Cod.menuScene.squad[index] then wanted[member.id] = true end
    end
    for id in pairs(CodSquad.shown) do
        if not wanted[id] then CodSquad.remove(id) end
    end
    if not Cod.menuOpen then return end

    local player = PlayerPedId()
    for index, member in ipairs(CodSquad.members) do
        local slot = Config.Cod.menuScene.squad[index]
        if not slot then break end
        if not CodSquad.shown[member.id] then CodSquad.create(member) end
        if not Cod.menuOpen then return CodSquad.clear() end
        local shown = CodSquad.shown[member.id]
        if shown then
            local coords = GetOffsetFromEntityInWorldCoords(player, slot.x, slot.y, 0.0)
            SetEntityCoordsNoOffset(shown.ped, coords.x, coords.y, coords.z, false, false, false)
            SetEntityHeading(shown.ped, GetEntityHeading(player))
            CodSquad.setWeapon(shown, member.weapon)
        end
    end
end

---@param member { id: integer, appearance: table|nil, weapon: string }
function CodSquad.create(member)
    local appearance = member.appearance or AppearanceSchema.default('male')
    local model = GetHashKey(AppearanceSchema.MODELS[appearance.sex] or AppearanceSchema.MODELS.male)
    if not PedUtils.loadModel(model) then return end

    local coords = GetEntityCoords(PlayerPedId())
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    Appearance.apply(ped, appearance)
    CodSquad.shown[member.id] = { ped = ped }
end

---@param shown { ped: integer, weapon: string|nil }
---@param weapon string
function CodSquad.setWeapon(shown, weapon)
    if shown.weapon == weapon then return end
    shown.weapon = weapon
    local hash = GetHashKey(weapon)
    RemoveAllPedWeapons(shown.ped, true)
    GiveWeaponToPed(shown.ped, hash, 1, false, true)
    SetCurrentPedWeapon(shown.ped, hash, true)
end

---@param id integer
function CodSquad.remove(id)
    local ped = CodSquad.shown[id].ped
    if DoesEntityExist(ped) then DeletePed(ped) end
    CodSquad.shown[id] = nil
end

---Sortie du salon ou du menu.
function CodSquad.clear()
    CodSquad.members = {}
    for id in pairs(CodSquad.shown) do CodSquad.remove(id) end
end
