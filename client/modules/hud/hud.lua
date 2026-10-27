---Envoie au HUD React l'état du ped : santé, armure, arme en main et munitions.
---N'envoie un message que si quelque chose a changé.
---@class HudModule
local Hud = PVP.define('Hud')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Items = PVP.use('Items')

Hud.INTERVAL = 200
Hud.weaponByHash = {} -- [hash GTA] = nom de l'objet arme
Hud.last = nil

function Hud.init()
    for name, item in pairs(Config.Items) do
        if item.type == 'weapon' then
            Hud.weaponByHash[GetHashKey(item.weapon)] = name
        end
    end
    CreateThread(Hud.loop)
end

function Hud.loop()
    while true do
        Wait(Hud.INTERVAL)
        if State.spawned then
            Hud.update()
        end
    end
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
end

function Hud.update()
    local data = Hud.collect()
    if Hud.last and Hud.equals(Hud.last, data) then return end
    Hud.last = data
    Nui.send('vitals', data)
end
