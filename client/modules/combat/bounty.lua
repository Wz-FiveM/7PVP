---Primes en cours : un repère rouge suit chaque joueur dont la tête est mise à prix
---(voir server/modules/combat/bounty_service.lua). La prime s'affiche aussi dans le HUD.
---@class BountyModule
local Bounty = PVP.define('Bounty')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Bounty.REFRESH_INTERVAL = 1000

---@type table[] { id, name, amount, streak }
Bounty.list = {}
---@type table<integer, integer> server id -> blip
Bounty.blips = {}

function Bounty.init()
    RegisterNetEvent(Events.client.bountySync, function(list)
        Bounty.list = type(list) == 'table' and list or {}
        Nui.send('bounties', Bounty.list)
        Bounty.refresh()
    end)
    CreateThread(Bounty.loop)
end

function Bounty.loop()
    while true do
        Wait(Bounty.REFRESH_INTERVAL)
        Bounty.refresh()
    end
end

---Un repère par joueur ciblé et chargé par le jeu (le sien excepté), seulement en PvP.
function Bounty.refresh()
    local wanted = {}
    local me = GetPlayerServerId(PlayerId())
    if State.inPvp() then
        for _, entry in ipairs(Bounty.list) do
            if entry.id ~= me and GetPlayerFromServerId(entry.id) ~= -1 then wanted[entry.id] = entry end
        end
    end

    for id, blip in pairs(Bounty.blips) do
        if not wanted[id] or not DoesBlipExist(blip) then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            Bounty.blips[id] = nil
        end
    end

    for id, entry in pairs(wanted) do
        if not Bounty.blips[id] then
            local blip = AddBlipForEntity(GetPlayerPed(GetPlayerFromServerId(id)))
            SetBlipSprite(blip, Config.Bounty.blip.sprite)
            SetBlipColour(blip, Config.Bounty.blip.color)
            SetBlipScale(blip, 1.0)
            SetBlipAsShortRange(blip, false)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(Locale.t('Prime : %s ($%d)', entry.name, entry.amount))
            EndTextCommandSetBlipName(blip)
            Bounty.blips[id] = blip
        end
    end
end
