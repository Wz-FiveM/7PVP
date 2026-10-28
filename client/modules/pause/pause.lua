---Menu pause 7PVP : remplace le menu pause de GTA (Échap / P) en jeu.
---Il donne accès à la carte et aux paramètres de GTA, à l'inventaire, au lobby et à la déconnexion.
---@class PauseModule
local Pause = PVP.define('Pause')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Admin = PVP.use('Admin')
local Lobby = PVP.use('Lobby')
local Freeroam = PVP.use('Freeroam')
local Events = PVP.use('Events')

Pause.CONTROL_ESCAPE = 200 -- INPUT_FRONTEND_PAUSE_ALTERNATE (Échap)
Pause.CONTROL_PAUSE = 199 -- INPUT_FRONTEND_PAUSE (P)
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
        if IsNuiFocused() or Pause.open then
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
    Nui.send('pause', { open = true, info = Pause.buildInfo() })
end

function Pause.close()
    if not Pause.open then return end
    Pause.open = false
    Pause.lastFocus = GetGameTimer()
    SetNuiFocus(false, false)
    Nui.send('pause', { open = false })
end

---@return table informations du compte affichées sur l'accueil
function Pause.buildInfo()
    local player = State.player or {}
    return {
        name = player.name or GetPlayerName(PlayerId()),
        serverId = GetPlayerServerId(PlayerId()),
        mode = State.mode,
        level = player.level or 1,
        kills = player.kills or 0,
        deaths = player.deaths or 0,
        npcKills = player.npcKills or 0,
        isAdmin = Admin.isAdmin,
        keys = {
            menu = Config.MenuKeyLabel,
            hotbar = Config.HotbarKey,
            chat = Config.Chat.key,
            admin = Config.Admin.Key,
            noclip = Config.Admin.NoclipKey,
            teleport = Config.Teleport.key,
        },
    }
end

-- Actions des boutons : nom -> méthode
Pause.ACTIONS = {
    map = 'openMap',
    settings = 'openSettings',
    menu = 'openGameMenu',
    lobby = 'backToLobby',
    quit = 'quit',
}

---@param action any
function Pause.runAction(action)
    local method = Pause.ACTIONS[action]
    if not method then return end
    Pause.close()
    Pause[method]()
end

---Carte de GTA (menu pause natif, directement sur l'onglet carte).
function Pause.openMap()
    CreateThread(function()
        Wait(Pause.FRONTEND_DELAY)
        ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'), false, -1)
        Wait(100)
        PauseMenuceptionGoDeeper(0)
    end)
end

---Menu pause de GTA, pour ses paramètres (graphismes, son, commandes...).
function Pause.openSettings()
    CreateThread(function()
        Wait(Pause.FRONTEND_DELAY)
        ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'), false, -1)
    end)
end

function Pause.openGameMenu()
    if State.mode == 'pvp' then Nui.setMenu(true) end
    if State.mode == 'freeroam' then Freeroam.setMenu(true) end
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
