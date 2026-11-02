---Primes en cours : un repère rouge suit chaque joueur dont la tête est mise à prix
---(voir server/modules/combat/bounty_service.lua). La prime s'affiche aussi dans le HUD.
---@class BountyModule
local Bounty = PVP.define('Bounty')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Callback = PVP.use('Callback')
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

    RegisterCommand('signaler', function(_, args)
        local target = tonumber(args[1])
        table.remove(args, 1)
        CreateThread(function()
            local result = Callback.await(Events.callbacks.reportPlayer, { target = target, reason = table.concat(args, ' ') })
            if result and result.message then Nui.notify(result.message, result.ok and 'success' or 'error') end
        end)
    end, false)
    RegisterCommand('prime', function(_, args)
        CreateThread(function()
            local result = Callback.await(Events.callbacks.bountyPlace, { target = tonumber(args[1]), amount = tonumber(args[2]) })
            if result and result.message then Nui.notify(result.message, result.ok and 'success' or 'error') end
        end)
    end, false)
    RegisterNUICallback('bountyPlace', function(data, cb)
        cb(Callback.await(Events.callbacks.bountyPlace, { target = tonumber(data.target), amount = tonumber(data.amount) }) or { ok = false })
    end)
    RegisterNUICallback('bountyTargets', function(_, cb)
        cb(Callback.await(Events.callbacks.bountyTargets) or { list = {} })
    end)
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
