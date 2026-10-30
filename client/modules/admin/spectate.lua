---Mode spectateur des admins : la caméra suit un joueur (course poursuite, CVC, jeu libre).
---Le serveur place l'admin dans le bucket du joueur et lui envoie sa position chaque seconde
---(voir SpectateService). Le personnage de l'admin, caché, gelé et sans collision, reste
---au-dessus du joueur : le jeu charge ainsi ce qui l'entoure (dont son personnage).
---Retour arrière : quitter ; flèches gauche / droite : autre joueur au même endroit.
---@class SpectateModule
local Spectate = PVP.define('Spectate')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local HelpNotify = PVP.use('HelpNotify')
local Noclip = PVP.use('Noclip')
local Admin = PVP.use('Admin')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Spectate.CONTROL_STOP = 194 -- INPUT_FRONTEND_RRIGHT (Retour arrière)
Spectate.CONTROL_PREVIOUS = 174 -- INPUT_CELLPHONE_LEFT (flèche gauche)
Spectate.CONTROL_NEXT = 175 -- INPUT_CELLPHONE_RIGHT (flèche droite)
Spectate.DISABLED_CONTROLS = { 24, 25, 37, 44, 140, 141, 142, 143, 174, 175, 194 }
Spectate.HEIGHT = 15.0 -- mètres au-dessus du joueur regardé
Spectate.MOVE_INTERVAL = 250 -- ms entre deux déplacements du personnage de l'admin

Spectate.active = false
Spectate.target = nil -- server id du joueur regardé
Spectate.name = ''
Spectate.label = nil -- situation du joueur (course, CVC), nil en jeu libre
Spectate.coords = nil -- dernière position envoyée par le serveur
Spectate.ped = 0 -- personnage suivi par la caméra
Spectate.returnTo = nil -- vector4 : où ramener l'admin à la fin
Spectate.nextMove = 0

function Spectate.init()
    RegisterNetEvent(Events.client.spectate, function(data)
        if type(data) == 'table' then
            Spectate.update(data)
        else
            Spectate.finish()
        end
    end)
end

---@return string|false nom du joueur regardé (affiché dans le panneau admin)
function Spectate.current()
    return Spectate.active and Spectate.name or false
end

---Début, changement de joueur ou nouvelle position.
---@param data { target: integer, name: string, label: string|false, coords: vector3 }
function Spectate.update(data)
    local changed = data.target ~= Spectate.target
    Spectate.target = data.target
    Spectate.name = data.name
    Spectate.label = data.label or nil
    Spectate.coords = data.coords
    if changed then Spectate.ped = 0 end

    if not Spectate.active then Spectate.begin() end
    if changed then Admin.refresh() end
end

function Spectate.begin()
    local ped = PlayerPedId()
    if Noclip.active then Noclip.set(false) end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then TaskLeaveVehicle(ped, vehicle, 16) end -- 16 : sort sur place, tout de suite

    local coords = GetEntityCoords(ped)
    Spectate.returnTo = vector4(coords.x, coords.y, coords.z, GetEntityHeading(ped))
    Spectate.active = true
    State.spectating = true
    Noclip.applyPedState()
    CreateThread(Spectate.loop)
end

---Fin demandée par le serveur (arrêt, joueur parti, passage au lobby).
function Spectate.finish()
    if not Spectate.active then return end
    Spectate.active = false
    State.spectating = false
    Spectate.target = nil
    Spectate.ped = 0
    NetworkSetInSpectatorMode(false, PlayerPedId())
    HelpNotify.hide()
    Admin.refresh()

    -- Au lobby, c'est le lobby qui gère le personnage
    if not State.mode then return end
    local back = Spectate.returnTo
    CreateThread(function()
        if back then
            Admin.teleport(back.xyz)
            SetEntityHeading(PlayerPedId(), back.w)
        end
        Noclip.applyPedState()
    end)
end

function Spectate.loop()
    while Spectate.active do
        Wait(0)
        Spectate.step()
    end
end

function Spectate.step()
    for _, control in ipairs(Spectate.DISABLED_CONTROLS) do
        DisableControlAction(0, control, true)
    end
    if IsDisabledControlJustPressed(0, Spectate.CONTROL_STOP) then
        TriggerServerEvent(Events.server.spectateStop)
    elseif IsDisabledControlJustPressed(0, Spectate.CONTROL_PREVIOUS) then
        TriggerServerEvent(Events.server.spectateNext, -1)
    elseif IsDisabledControlJustPressed(0, Spectate.CONTROL_NEXT) then
        TriggerServerEvent(Events.server.spectateNext, 1)
    end

    local situation = Spectate.label and (' · ' .. Locale.resolve(Spectate.label)) or ''
    HelpNotify.show(Locale.t('Retour'), Locale.t('Quitter · %s%s · ← → autre joueur', Spectate.name, situation))

    local now = GetGameTimer()
    if now < Spectate.nextMove then return end
    Spectate.nextMove = now + Spectate.MOVE_INTERVAL
    Spectate.follow()
end

---Caméra sur le joueur dès que son personnage est chargé, et personnage de l'admin au-dessus de lui.
function Spectate.follow()
    local player = GetPlayerFromServerId(Spectate.target)
    local targetPed = player ~= -1 and GetPlayerPed(player) or 0
    local coords = Spectate.coords
    if targetPed ~= 0 and DoesEntityExist(targetPed) then
        coords = GetEntityCoords(targetPed)
        -- Nouveau personnage (joueur changé, réapparition) : la caméra le reprend
        if targetPed ~= Spectate.ped then
            Spectate.ped = targetPed
            NetworkSetInSpectatorMode(true, targetPed)
        end
    end
    if not coords then return end

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + Spectate.HEIGHT, false, false, false)
end
