---Personnages du mode Call of Duty (server/modules/cod/cod_operator_service.lua) : le serveur valide l'accès, le client
---porte le modèle et le montre dans le menu. Un modèle absent de la ressource 7PVP_operators n'est jamais chargé.
---@class CodOperatorsModule
local CodOperators = PVP.define('CodOperators')
local Cod = PVP.use('Cod')
local Appearance = PVP.use('Appearance')
local AppearanceSchema = PVP.use('AppearanceSchema')
local PedUtils = PVP.use('PedUtils')
local State = PVP.use('State')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

CodOperators.PREVIEW_TIMEOUT = 10000 -- ms d'attente du modèle : le menu ne doit pas rester bloqué

---@type table<string, table> entrées de Config.CodOperators.list par id
CodOperators.byId = {}
---@type string|false|nil dernier personnage demandé par le menu ; false = celui du joueur, nil = le choix enregistré
CodOperators.wanted = nil

function CodOperators.init()
    for _, entry in ipairs(Config.CodOperators.list) do CodOperators.byId[entry.id] = entry end

    RegisterNUICallback('codOperatorPreview', function(data, cb)
        cb({})
        CodOperators.preview(data.id)
    end)
    RegisterNUICallback('codOperatorSelect', function(data, cb)
        cb(Cod.storeProfile(Callback.await(Events.callbacks.codSelectOperator, data.id)))
    end)
    RegisterNUICallback('codOperatorBuy', function(data, cb)
        -- L'interface garde le bouton inactif : le joueur ne paie jamais un modèle absent du jeu
        local entry = CodOperators.byId[data.id]
        if not entry or not CodOperators.isInstalled(entry.model) then return cb({ ok = false }) end
        cb(Cod.storeProfile(Callback.await(Events.callbacks.codBuyOperator, data.id)))
    end)
end

---@param model string|false
---@return boolean le modèle existe dans le jeu
function CodOperators.isInstalled(model)
    if not model then return false end
    local hash = GetHashKey(model)
    return IsModelInCdimage(hash) and IsModelAPed(hash)
end

---Le serveur ne sait pas quels modèles sont dans le jeu : le menu l'apprend ici.
---@param catalog table
function CodOperators.markInstalled(catalog)
    for _, entry in ipairs(catalog.operators) do
        entry.available = CodOperators.isInstalled(entry.model)
    end
end

---@return integer modèle à montrer pour la demande en cours
function CodOperators.wantedModel()
    local wanted = CodOperators.wanted
    local model = wanted == nil and Cod.profile.operatorModel or (wanted and CodOperators.byId[wanted].model)
    if CodOperators.isInstalled(model) then return GetHashKey(model) end
    return GetHashKey(AppearanceSchema.MODELS[State.appearance.sex] or AppearanceSchema.MODELS.male)
end

---@param id string|nil 'own' pour le personnage du joueur, nil pour le choix enregistré
function CodOperators.preview(id)
    if id == 'own' then
        CodOperators.wanted = false
    else
        CodOperators.wanted = CodOperators.byId[id] and id or nil
    end
    Cod.exclusive(CodOperators.showWanted)
end

---Change le personnage du menu. Seule la dernière demande compte : le joueur fait défiler la liste.
function CodOperators.showWanted()
    if not Cod.menuOpen or not Cod.profile then return end
    local wanted = CodOperators.wanted
    local model = CodOperators.wantedModel()
    if not PedUtils.loadModel(model, CodOperators.PREVIEW_TIMEOUT) then return end
    if not Cod.menuOpen or CodOperators.wanted ~= wanted then return end

    local before = PlayerPedId()
    local coords, heading = GetEntityCoords(before), GetEntityHeading(before)
    if not Appearance.setPlayerModel(model) then return end

    -- Le changement de modèle crée un autre ped : les réglages du menu sont à refaire (Cod.openMenu)
    local ped = PlayerPedId()
    Appearance.apply(ped, State.appearance)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    Cod.previewClass()
end
