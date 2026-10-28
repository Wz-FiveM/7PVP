---Pont entre Lua et l'interface React (web/).
---Lua -> React : Nui.send(action, data)
---React -> Lua : callbacks NUI enregistrés dans Nui.init()
---@class NuiModule
local Nui = PVP.define('Nui')
local State = PVP.use('State')
local Callback = PVP.use('Callback')
local Inventory = PVP.use('Inventory')
local Hud = PVP.use('Hud')
local Zones = PVP.use('Zones')
local Freeroam = PVP.use('Freeroam')
local SafeNpcs = PVP.use('SafeNpcs')
local Events = PVP.use('Events')

function Nui.init()
    -- Nouveau nom de commande à chaque changement de touche par défaut : FiveM garde sinon
    -- la touche déjà enregistrée par les joueurs qui ont joué avant
    RegisterCommand('pvp_inventaire', function()
        Nui.toggleMenu()
    end, false)
    RegisterKeyMapping('pvp_inventaire', 'Ouvrir l\'inventaire 7PVP', 'keyboard', Config.MenuKey)

    RegisterNUICallback('ready', function(_, cb)
        Hud.invalidate()
        cb(Nui.buildInitPayload())
    end)

    RegisterNUICallback('close', function(_, cb)
        Nui.setMenu(false)
        cb({})
    end)

    RegisterNUICallback('buy', function(data, cb)
        cb(Callback.await(Events.callbacks.buy, data.index) or { ok = false })
    end)

    RegisterNUICallback('useItem', function(data, cb)
        cb(Callback.await(Events.callbacks.useItem, data.name) or { ok = false })
    end)

    RegisterNUICallback('equip', function(data, cb)
        Inventory.equip(data.name)
        cb({ ok = true })
    end)

    RegisterNUICallback('moveItem', function(data, cb)
        cb(Callback.await(Events.callbacks.moveItem, data) or { ok = false })
    end)

    RegisterNUICallback('dropItem', function(data, cb)
        cb(Callback.await(Events.callbacks.dropItem, data) or { ok = false })
    end)

    RegisterNUICallback('setShortcut', function(data, cb)
        cb(Callback.await(Events.callbacks.setShortcut, data.slot, data.item) or { ok = false })
    end)

    -- Place de marché : chaque action est vérifiée par le serveur (près du commissaire-priseur)
    RegisterNUICallback('marketList', function(_, cb)
        cb(Callback.await(Events.callbacks.marketList) or { listings = {}, balance = 0 })
    end)
    RegisterNUICallback('marketSell', function(data, cb)
        cb(Callback.await(Events.callbacks.marketSell, data) or { ok = false })
    end)
    RegisterNUICallback('marketBuy', function(data, cb)
        cb(Callback.await(Events.callbacks.marketBuy, data.id) or { ok = false })
    end)
    RegisterNUICallback('marketCancel', function(data, cb)
        cb(Callback.await(Events.callbacks.marketCancel, data.id) or { ok = false })
    end)
    RegisterNUICallback('marketCollect', function(_, cb)
        cb(Callback.await(Events.callbacks.marketCollect) or { ok = false })
    end)

    RegisterNUICallback('craft', function(data, cb)
        cb(Callback.await(Events.callbacks.craft, data.id) or { ok = false })
    end)

    RegisterNUICallback('attachment', function(data, cb)
        cb(Callback.await(Events.callbacks.attachment, data) or { ok = false })
    end)

    RegisterNUICallback('leaderboard', function(data, cb)
        cb(Callback.await(Events.callbacks.leaderboard, data.scope) or { rows = {}, title = '' })
    end)

    RegisterNetEvent(Events.client.notify, function(message, kind)
        Nui.notify(message, kind)
    end)

    RegisterNetEvent(Events.client.killfeed, function(entry)
        Nui.send('killfeed', entry)
    end)
end

---@param action string
---@param data? any
function Nui.send(action, data)
    SendNUIMessage({ action = action, data = data })
end

---@param text string
---@param kind? 'info'|'success'|'error'
function Nui.notify(text, kind)
    Nui.send('notify', { text = text, kind = kind or 'info' })
end

---@return table
function Nui.buildInitPayload()
    return {
        config = {
            shop = Config.Shop,
            items = Config.Items,
            containers = Config.Containers,
            shortcutSlots = Config.ShortcutSlots,
            xpPerLevel = Config.XpPerLevel,
            groupMaxSize = Config.Groups.maxSize,
            menuKey = Config.MenuKeyLabel,
            attachments = Config.Attachments,
            recipes = Config.Recipes,
        },
        player = State.player,
        zone = Zones.toInfo(State.zone),
    }
end

---@param page? string page à afficher (ex : 'shop' en parlant à l'armurier)
function Nui.sendMenuState(page)
    Nui.send('menu', {
        open = State.menuOpen,
        inSafe = State.isInSafeZone(),
        -- Services des PNJ de la zone safe à portée (coffre, boutique, fabrication...)
        near = SafeNpcs.nearRoles(GetEntityCoords(PlayerPedId())),
        page = page,
    })
end

---@param open boolean
---@param page? string
function Nui.setMenu(open, page)
    if open and not State.isAlive() then return end
    State.menuOpen = open
    SetNuiFocus(open, open)
    Nui.sendMenuState(page)
end

function Nui.toggleMenu()
    -- En Freeroam, la touche du menu ouvre le menu des armes et véhicules
    if State.mode == 'freeroam' then return Freeroam.toggleMenu() end
    Nui.setMenu(not State.menuOpen)
end
