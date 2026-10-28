---Échanges entre joueurs côté client : commande /trade, demandes reçues et fenêtre d'échange
---(à droite de l'inventaire). Fermer le menu annule l'échange.
---Le serveur décide de tout (voir server/modules/trade/trade_service.lua).
---@class TradeModule
local Trade = PVP.define('Trade')
local Nui = PVP.use('Nui')
local Loot = PVP.use('Loot')
local Interaction = PVP.use('Interaction')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

Trade.USAGE = 'Utilisation : /trade [ID] · /trade accepter · /trade refuser · /trade annuler'

---@type table|false échange en cours { id, partner, mine, theirs }
Trade.data = false

function Trade.init()
    RegisterNetEvent(Events.client.tradeRequest, function(request)
        Trade.onRequest(request)
    end)
    RegisterNetEvent(Events.client.tradeState, function(data)
        Trade.onState(data)
    end)

    -- Commande du chat (T puis /trade ...)
    RegisterCommand('trade', function(_, args)
        Trade.command(args[1])
    end, false)

    -- Fenêtre d'échange de l'inventaire
    RegisterNUICallback('tradeOffer', function(data, cb)
        if type(data) ~= 'table' then return cb({ ok = false }) end
        cb(Callback.await(Events.callbacks.tradeOffer, { item = data.item, count = data.count }) or { ok = false })
    end)
    RegisterNUICallback('tradeReady', function(data, cb)
        cb(Callback.await(Events.callbacks.tradeReady, type(data) == 'table' and data.ready == true) or { ok = false })
    end)
    RegisterNUICallback('tradeConfirm', function(_, cb)
        cb(Callback.await(Events.callbacks.tradeConfirm) or { ok = false })
    end)
    RegisterNUICallback('tradeCancel', function(_, cb)
        cb(Callback.await(Events.callbacks.tradeCancel) or { ok = false })
    end)
end

---@param arg string|nil ID du joueur, accepter, refuser, annuler ; rien = le joueur le plus proche
function Trade.command(arg)
    if arg == 'accepter' or arg == 'refuser' then
        return Trade.request(Events.callbacks.tradeRespond, arg == 'accepter')
    end
    if arg == 'annuler' then return Trade.request(Events.callbacks.tradeCancel) end
    if arg and not tonumber(arg) then return Nui.notify(Trade.USAGE, 'error') end

    local target = tonumber(arg)
    if not target then
        local nearest = Interaction.nearestPlayer()
        if not nearest then return Nui.notify('Personne à côté de toi. ' .. Trade.USAGE, 'error') end
        target = GetPlayerServerId(nearest)
    end
    Trade.request(Events.callbacks.tradeRequest, target)
end

---Le résultat s'affiche en notification.
---@param name string callback serveur
---@param ... any
function Trade.request(name, ...)
    local args = { ... }
    CreateThread(function()
        local result = Callback.await(name, table.unpack(args))
        if result and result.message then
            Nui.notify(result.message, result.ok and 'success' or 'error')
        end
    end)
end

---@param request { from: integer, fromName: string }
function Trade.onRequest(request)
    Nui.notify(('%s te propose un échange : /trade accepter ou /trade refuser.'):format(request.fromName), 'info')
end

---Échange mis à jour par le serveur, false : terminé ou annulé.
---@param data table|false
function Trade.onState(data)
    local starting = data and not Trade.data
    Trade.data = data or false
    Nui.send('trade', { trade = Trade.data })
    if starting then
        -- L'échange prend la place d'un butin ouvert, à droite de l'inventaire
        Loot.closeContainer()
        Nui.setMenu(true, 'inventory')
    end
end

---Appelé à la fermeture du menu.
function Trade.closeWindow()
    if not Trade.data then return end
    Trade.request(Events.callbacks.tradeCancel)
end
