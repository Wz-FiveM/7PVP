---Menu pause 7PVP : remplace le menu pause de GTA (Échap / P) en jeu.
---Il donne accès à la carte et aux paramètres de GTA, à l'inventaire, au lobby et à la déconnexion.
---@class PauseModule
local Pause = PVP.define('Pause')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Admin = PVP.use('Admin')
local Lobby = PVP.use('Lobby')
local Freeroam = PVP.use('Freeroam')
local Cod = PVP.use('Cod')
local Teleport = PVP.use('Teleport')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Hud = PVP.use('Hud')

Pause.CONTROL_ESCAPE = 200 -- INPUT_FRONTEND_PAUSE_ALTERNATE (Échap)
Pause.CONTROL_PAUSE = 199 -- INPUT_FRONTEND_PAUSE (P)
Pause.CONTROL_CANCEL = 202 -- INPUT_FRONTEND_CANCEL (Retour)
-- Après la fermeture d'une interface, la touche Échap relâchée ne doit pas rouvrir la pause
Pause.FOCUS_GRACE = 400
-- Délai avant d'ouvrir un menu de GTA (le focus de l'interface doit être rendu au jeu)
Pause.FRONTEND_DELAY = 150

Pause.open = false
Pause.lastFocus = 0

function Pause.init()
    RegisterNUICallback('pauseClose', function(_, cb)
        Pause.close()
        cb({})
    end)
    RegisterNUICallback('pauseAction', function(data, cb)
        cb({})
        Pause.runAction(data.action)
    end)
    CreateThread(Pause.loop)
end

---Hors lobby et créateur, Échap et P ouvrent ce menu au lieu de celui de GTA.
function Pause.loop()
    while true do
        Wait(0)
        if IsNuiFocused() or Pause.open or IsPauseMenuActive() then
            Pause.lastFocus = GetGameTimer()
        end

        if State.mode and not IsPauseMenuActive() then
            DisableControlAction(0, Pause.CONTROL_ESCAPE, true)
            DisableControlAction(0, Pause.CONTROL_PAUSE, true)
            local pressed = IsDisabledControlJustReleased(0, Pause.CONTROL_ESCAPE)
                or IsDisabledControlJustReleased(0, Pause.CONTROL_PAUSE)
            if pressed and GetGameTimer() - Pause.lastFocus > Pause.FOCUS_GRACE then
                Pause.show()
            end
        end
    end
end

function Pause.show()
    if Pause.open then return end
    Pause.open = true
    SetNuiFocus(true, true)
    Cod.onPause(true)
    Nui.send('pause', { open = true, info = Pause.buildInfo() })
end

function Pause.close()
    if not Pause.open then return end
    Pause.open = false
    Pause.lastFocus = GetGameTimer()
    SetNuiFocus(false, false)
    Cod.onPause(false)
    Nui.send('pause', { open = false })
end

---@return table informations du compte affichées sur l'accueil
function Pause.buildInfo()
    local player = State.player or {}
    return {
        name = player.name or GetPlayerName(PlayerId()),
        serverId = GetPlayerServerId(PlayerId()),
        avatar = player.avatar,
        mode = State.mode,
        level = player.level or 1,
        kills = player.kills or 0,
        deaths = player.deaths or 0,
        npcKills = player.npcKills or 0,
        isAdmin = Admin.isAdmin,
        keys = {
            menu = Config.MenuKeyLabel,
            chat = Config.Chat.key,
            admin = Config.Admin.Key,
            noclip = Config.Admin.NoclipKey,
            teleport = Config.Teleport.key,
            codClass = Config.Cod.classKey,
            codStreak = Config.Cod.streakKey,
            codPrimary = Config.Cod.primaryKey,
            codSecondary = Config.Cod.secondaryKey,
            codEquipment = Config.Cod.equipmentKey,
            codTactical = Config.Cod.tacticalKey,
            codPlate = Config.CodWarzone.plateKey,
        },
    }
end

-- Actions des boutons : nom -> méthode
Pause.ACTIONS = {
    map = 'openMap',
    settings = 'openSettings',
    menu = 'openGameMenu',
    teleport = 'openTeleport',
    lobby = 'backToLobby',
    codLeave = 'leaveCodMatch',
    quit = 'quit',
}

---@param action any
function Pause.runAction(action)
    local method = Pause.ACTIONS[action]
    if not method then return end
    Pause.close()
    Pause[method]()
end

---@return boolean Échap ou Retour pressé (contrôles joueur ou frontend)
function Pause.cancelPressed()
    for _, pad in ipairs({ 0, 2 }) do
        if IsDisabledControlJustPressed(pad, Pause.CONTROL_CANCEL)
            or IsDisabledControlJustPressed(pad, Pause.CONTROL_ESCAPE) then
            return true
        end
    end
    return false
end

---Ouvre le menu pause de GTA en laissant d'abord la minimap au jeu (voir Hud.blockMinimap).
function Pause.activateFrontend()
    Hud.blockMinimap()
    ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'), false, -1)
end

---Carte de GTA (menu pause natif, directement sur l'onglet carte).
---Échap la ferme d'un coup au lieu de remonter aux onglets du menu pause.
function Pause.openMap()
    CreateThread(function()
        Wait(Pause.FRONTEND_DELAY)
        Pause.activateFrontend()
        Wait(100)
        PauseMenuceptionGoDeeper(0)
        while IsPauseMenuActive() do
            -- Le menu ne doit pas traiter Échap lui-même : sa fermeture s'ajouterait à la nôtre
            for _, pad in ipairs({ 0, 2 }) do
                DisableControlAction(pad, Pause.CONTROL_CANCEL, true)
                DisableControlAction(pad, Pause.CONTROL_ESCAPE, true)
            end
            if Pause.cancelPressed() then
                Hud.blockMinimap()
                SetFrontendActive(false)
                break
            end
            Wait(0)
        end
    end)
end

---Menu pause de GTA, pour ses paramètres (graphismes, son, commandes...).
function Pause.openSettings()
    CreateThread(function()
        Wait(Pause.FRONTEND_DELAY)
        Pause.activateFrontend()
    end)
end

---Menu de téléportation entre zones safe (comme sa touche).
function Pause.openTeleport()
    CreateThread(function()
        Wait(Pause.FRONTEND_DELAY)
        Teleport.toggle()
    end)
end

function Pause.openGameMenu()
    if State.mode == 'pvp' then Nui.setMenu(true) end
    if State.mode == 'freeroam' then Freeroam.setMenu(true) end
end

---Call of Duty : quitte la partie, retour au menu du mode.
function Pause.leaveCodMatch()
    CreateThread(function()
        Callback.await(Events.callbacks.codLeaveMatch)
    end)
end

---Comme /lobby : refusé (avec message) hors zone safe ou en combat.
function Pause.backToLobby()
    CreateThread(function()
        local result = Lobby.requestLeave()
        if not result.ok and result.message then Nui.notify(result.message, 'error') end
    end)
end

function Pause.quit()
    TriggerServerEvent(Events.server.quit)
end
