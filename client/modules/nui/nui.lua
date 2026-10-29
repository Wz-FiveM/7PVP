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
local Loot = PVP.use('Loot')
local Trade = PVP.use('Trade')
local Lobby = PVP.use('Lobby')
local Events = PVP.use('Events')

-- Commandes coupées quand le menu laisse le clavier au jeu : caméra et roue de la souris, tir,
-- visée, corps à corps, roue des armes, armes et radio du véhicule, menu pause de GTA
Nui.MENU_BLOCKED_CONTROLS = { 1, 2, 14, 15, 16, 17, 24, 25, 37, 68, 69, 70, 81, 82, 91, 92, 99, 100, 106, 140, 141, 142, 143, 199, 200, 257, 263 }
Nui.TOGGLE_DEBOUNCE = 300 -- ms
Nui.gameInput = false
Nui.gameInputChangedAt = 0
Nui.typing = false

function Nui.init()
    -- Nouveau nom de commande à chaque changement de touche par défaut : FiveM garde sinon
    -- la touche déjà enregistrée par les joueurs qui ont joué avant
    RegisterCommand('pvp_menu_tab', function()
        Nui.toggleMenu()
    end, false)
    RegisterKeyMapping('pvp_menu_tab', 'Ouvrir l\'inventaire / le menu 7PVP', 'keyboard', Config.MenuKey)

    RegisterNUICallback('ready', function(_, cb)
        Hud.invalidate()
        cb(Nui.buildInitPayload())
    end)

    RegisterNUICallback('close', function(_, cb)
        Nui.setMenu(false)
        cb({})
    end)

    -- Une partie de l'interface a planté (web/src/components/ui/UiGuard.tsx)
    RegisterNUICallback('uiError', function(data, cb)
        cb({})
        Nui.onUiError(data)
    end)

    -- Saisie dans un champ du menu : le clavier ne va plus au jeu (sinon taper « 1 » sort une arme)
    RegisterNUICallback('menuTyping', function(data, cb)
        Nui.setTyping(type(data) == 'table' and data.typing == true)
        cb({})
    end)

    RegisterNUICallback('buy', function(data, cb)
        cb(Callback.await(Events.callbacks.buy, data.index) or { ok = false })
    end)

    -- Caisses : achat chez l'armurier, ouverture n'importe où hors combat (tirage côté serveur)
    RegisterNUICallback('caseBuy', function(data, cb)
        cb(Callback.await(Events.callbacks.caseBuy, data.id) or { ok = false })
    end)
    RegisterNUICallback('caseOpen', function(data, cb)
        cb(Callback.await(Events.callbacks.caseOpen, data.id) or { ok = false })
    end)
    RegisterNUICallback('caseOpenPoints', function(data, cb)
        cb(Callback.await(Events.callbacks.caseOpenPoints, data.id) or { ok = false })
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

    RegisterNUICallback('unlockStash', function(data, cb)
        cb(Callback.await(Events.callbacks.unlockStash, data.id) or { ok = false })
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
            cases = Config.Cases,
            caseRarities = Config.CaseRarities,
            shopPoints = {
                label = Config.ShopPoints.label,
                short = Config.ShopPoints.short,
                storeUrl = Config.ShopPoints.storeUrl ~= '' and Config.ShopPoints.storeUrl or nil,
            },
        },
        player = State.player,
        zone = Zones.toInfo(State.zone),
        -- Un message « mode » envoyé avant que la page soit prête serait perdu
        mode = State.mode or false,
        -- Idem pour l'ouverture du lobby à la connexion (page encore en chargement)
        lobby = Lobby.active and { open = true, modes = Lobby.modes } or nil,
    }
end

---Erreur d'une partie de l'interface : console F8 et journal du serveur (pour la corriger).
---@param data any { name, message }
function Nui.onUiError(data)
    if type(data) ~= 'table' then return end
    local name = tostring(data.name or '?'):sub(1, 40)
    local message = tostring(data.message or '?'):sub(1, 300)
    print(('[7PVP] interface « %s » : %s'):format(name, message))
    TriggerServerEvent(Events.server.uiError, name, message)
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
    -- Un butin ouvert (largage) se referme avec le menu ; un échange en cours est annulé
    if not open then
        Loot.closeContainer()
        Trade.closeWindow()
    end
    State.menuOpen = open
    SetNuiFocus(open, open)
    Nui.setGameInput(open)
    Nui.sendMenuState(page)
end

function Nui.toggleMenu()
    -- Menu ouvert, la touche arrive à la fois à l'interface (qui ferme) et au jeu : un seul changement
    if GetGameTimer() - Nui.gameInputChangedAt < Nui.TOGGLE_DEBOUNCE then return end
    -- En Freeroam, la touche du menu ouvre le menu des armes et véhicules
    if State.mode == 'freeroam' then return Freeroam.toggleMenu() end
    Nui.setMenu(not State.menuOpen)
end

-- ---------------------------------------------------------------------------
-- Clavier du jeu menu ouvert
-- ---------------------------------------------------------------------------

---Menu ouvert sans bloquer le jeu : on marche, on conduit et on utilise ses raccourcis (1 à 7)
---au clavier ; la souris reste au curseur (caméra, tir et roue des armes coupés).
---@param enabled boolean
function Nui.setGameInput(enabled)
    Nui.gameInputChangedAt = GetGameTimer()
    Nui.typing = false
    SetNuiFocusKeepInput(enabled)
    local wasEnabled = Nui.gameInput
    Nui.gameInput = enabled
    if enabled and not wasEnabled then CreateThread(Nui.gameInputLoop) end
end

---@param typing boolean un champ de texte du menu a le focus
function Nui.setTyping(typing)
    if not Nui.gameInput or typing == Nui.typing then return end
    Nui.typing = typing
    SetNuiFocusKeepInput(not typing)
end

function Nui.gameInputLoop()
    while Nui.gameInput do
        for _, control in ipairs(Nui.MENU_BLOCKED_CONTROLS) do
            DisableControlAction(0, control, true)
        end
        Wait(0)
    end
end
