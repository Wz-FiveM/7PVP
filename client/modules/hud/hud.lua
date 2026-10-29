---Pont entre le jeu et le HUD React :
---  - envoie l'état du ped (santé, armure, arme en main, munitions) quand il change ;
---  - envoie la position de la minimap GTA pour placer le HUD à côté ;
---  - masque le HUD natif de GTA que le HUD React remplace.
---@class HudModule
local Hud = PVP.define('Hud')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Items = PVP.use('Items')

Hud.INTERVAL = 200
Hud.MINIMAP_INTERVAL = 1000

-- Composants du HUD natif masqués : étoiles de recherche, icône d'arme, argent, nom du
-- véhicule, de la zone et de la rue, gains d'argent, roue et stats des armes.
-- Le réticule (14) est conservé.
Hud.HIDDEN_COMPONENTS = { 1, 2, 3, 4, 6, 7, 8, 9, 13, 19, 20 }

-- Scaleform de la minimap : sert à masquer ses barres natives de vie et d'armure
Hud.MINIMAP_HIDE_HEALTH_ARMOUR = 3
Hud.minimapScaleform = nil
-- Le menu pause met encore quelques images à s'ouvrir ou se refermer quand IsPauseMenuActive
-- ne le signale pas : piloter la minimap pendant ce temps fait crasher le jeu
Hud.PAUSE_MENU_COOLDOWN = 1500
Hud.minimapBlockedUntil = 0

Hud.weaponByHash = {} -- [hash GTA] = nom de l'objet arme
Hud.last = nil
Hud.lastMinimap = nil

function Hud.init()
    for name, item in pairs(Config.Items) do
        if item.type == 'weapon' then
            Hud.weaponByHash[GetHashKey(item.weapon)] = name
        end
    end
    CreateThread(Hud.loop)
    CreateThread(Hud.minimapLoop)
    CreateThread(Hud.nativeHudLoop)
    AddEventHandler('onResourceStop', Hud.onResourceStop)
end

function Hud.loop()
    while true do
        Wait(Hud.INTERVAL)
        if State.spawned then
            Hud.update()
        end
    end
end

function Hud.minimapLoop()
    while true do
        Hud.updateMinimap()
        Wait(Hud.MINIMAP_INTERVAL)
    end
end

function Hud.nativeHudLoop()
    Hud.loadMinimapScaleform()
    while true do
        Wait(0)
        for _, component in ipairs(Hud.HIDDEN_COMPONENTS) do
            HideHudComponentThisFrame(component)
        end
        DisplayAmmoThisFrame(false)
        -- Carte du menu pause ouverte : le jeu reprend la main sur la minimap, ne pas y toucher
        -- (piloter son scaleform à ce moment-là fait crasher le jeu)
        if IsPauseMenuActive() or IsPauseMenuRestarting() then
            Hud.blockMinimap()
        end
        if GetGameTimer() >= Hud.minimapBlockedUntil then
            -- La minimap ne doit jamais rester en grand (bascule du scaleform, touche Z)
            if IsBigmapActive() then
                SetRadarBigmapEnabled(false, false)
            end
            Hud.hideMinimapHealthArmour()
        end
    end
end

---Laisse la minimap au jeu pendant l'ouverture ou la fermeture du menu pause.
function Hud.blockMinimap()
    Hud.minimapBlockedUntil = GetGameTimer() + Hud.PAUSE_MENU_COOLDOWN
end

function Hud.loadMinimapScaleform()
    while IsPauseMenuActive() do Wait(100) end
    local scaleform = RequestScaleformMovie('minimap')
    while not HasScaleformMovieLoaded(scaleform) do Wait(0) end

    -- Bascule le radar en grand puis en petit pour qu'il prenne en compte le scaleform
    -- (le retour en petit est aussi forcé à chaque image dans nativeHudLoop)
    SetRadarBigmapEnabled(true, false)
    Wait(100)
    SetRadarBigmapEnabled(false, false)

    Hud.minimapScaleform = scaleform
end

---Libère le scaleform à l'arrêt de la ressource : un `ensure` en jeu en recrée un autre.
---@param resource string
function Hud.onResourceStop(resource)
    if resource ~= GetCurrentResourceName() or not Hud.minimapScaleform then return end
    local scaleform = Hud.minimapScaleform
    Hud.minimapScaleform = nil
    SetScaleformMovieAsNoLongerNeeded(scaleform)
end

---Masque les barres de vie et d'armure sous la minimap (le HUD React les remplace).
---À appeler à chaque image : le jeu les réaffiche sinon.
function Hud.hideMinimapHealthArmour()
    if not Hud.minimapScaleform or not HasScaleformMovieLoaded(Hud.minimapScaleform) then return end
    BeginScaleformMovieMethod(Hud.minimapScaleform, 'SETUP_HEALTH_ARMOUR')
    ScaleformMovieMethodAddParamInt(Hud.MINIMAP_HIDE_HEALTH_ARMOUR)
    EndScaleformMovieMethod()
end

---@return table
function Hud.collect()
    local ped = PlayerPedId()
    local hash = GetSelectedPedWeapon(ped)
    local weapon = Hud.weaponByHash[hash]
    local item = Items.get(weapon)

    -- La vie d'un joueur va de 100 (mort) à 200 : on la ramène sur 0..100
    local data = {
        health = math.max(0, GetEntityHealth(ped) - 100),
        maxHealth = math.max(1, GetEntityMaxHealth(ped) - 100),
        armor = GetPedArmour(ped),
        weapon = weapon or false,
        clip = 0,
        reserve = 0,
    }

    if item and item.ammo then
        local _, clip = GetAmmoInClip(ped, hash)
        data.clip = clip
        data.reserve = math.max(0, GetAmmoInPedWeapon(ped, hash) - clip)
    end
    return data
end

---Position de la minimap, en fractions de l'écran (0 à 1), selon la résolution,
---le format et la zone de sécurité réglée dans les options du jeu.
---@return table
function Hud.getMinimapAnchor()
    local safezone = GetSafeZoneSize()
    local margin = (1.0 / 20.0) * (math.abs(safezone - 1.0) * 10)
    local aspectRatio = GetAspectRatio(false)
    local resX, resY = GetActiveScreenResolution()

    local width = (resX / (4 * aspectRatio)) / resX
    local height = (resY / 5.674) / resY
    local left = margin
    local bottom = 1.0 - margin

    return {
        visible = not IsRadarHidden(),
        left = left,
        right = left + width,
        top = bottom - height,
        bottom = bottom,
    }
end

---@param a table
---@param b table
---@return boolean
function Hud.equals(a, b)
    for key, value in pairs(a) do
        if b[key] ~= value then return false end
    end
    return true
end

---Force le prochain envoi (ex : l'interface vient de se charger).
function Hud.invalidate()
    Hud.last = nil
    Hud.lastMinimap = nil
end

function Hud.update()
    local data = Hud.collect()
    if Hud.last and Hud.equals(Hud.last, data) then return end
    Hud.last = data
    Nui.send('vitals', data)
end

function Hud.updateMinimap()
    local data = Hud.getMinimapAnchor()
    if Hud.lastMinimap and Hud.equals(Hud.lastMinimap, data) then return end
    Hud.lastMinimap = data
    Nui.send('minimap', data)
end
