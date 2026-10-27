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
local Events = PVP.use('Events')

function Nui.init()
    RegisterCommand('pvp_menu', function()
        Nui.toggleMenu()
    end, false)
    RegisterKeyMapping('pvp_menu', 'Ouvrir le menu 7PVP', 'keyboard', Config.MenuKey)

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

    RegisterNUICallback('leaderboard', function(_, cb)
        cb(Callback.await(Events.callbacks.leaderboard) or {})
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
        },
        player = State.player,
        zone = Zones.toInfo(State.zone),
    }
end

function Nui.sendMenuState()
    Nui.send('menu', { open = State.menuOpen, inSafe = State.isInSafeZone() })
end

---@param open boolean
function Nui.setMenu(open)
    if open and not State.isAlive() then return end
    State.menuOpen = open
    SetNuiFocus(open, open)
    Nui.sendMenuState()
end

function Nui.toggleMenu()
    Nui.setMenu(not State.menuOpen)
end
