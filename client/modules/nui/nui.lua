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
local Crew = PVP.use('Crew')
local Control = PVP.use('Control')
local Lobby = PVP.use('Lobby')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local Language = PVP.use('Language')
local Dungeon = PVP.use('Dungeon')

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
    RegisterKeyMapping('pvp_menu_tab', Locale.t('Ouvrir l\'inventaire / le menu 7PVP'), 'keyboard', Config.MenuKey)

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
        cb(Callback.await(Events.callbacks.buy, data.index, data.quantity) or { ok = false })
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
    RegisterNUICallback('caseSkip', function(_, cb)
        cb(Callback.await(Events.callbacks.caseSkip) or { ok = false })
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

    RegisterNUICallback('loadoutSetSave', function(data, cb)
        cb(Callback.await(Events.callbacks.loadoutSetSave, data.slot) or { ok = false })
    end)
    RegisterNUICallback('loadoutSetApply', function(data, cb)
        cb(Callback.await(Events.callbacks.loadoutSetApply, data.slot) or { ok = false })
    end)
    RegisterNUICallback('loadoutSetClear', function(data, cb)
        cb(Callback.await(Events.callbacks.loadoutSetClear, data.slot) or { ok = false })
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

    -- Revente au receleur : prix et vente vérifiés par le serveur
    RegisterNUICallback('resaleList', function(_, cb)
        cb(Callback.await(Events.callbacks.resaleList) or { prices = {} })
    end)
    RegisterNUICallback('resaleSell', function(data, cb)
        cb(Callback.await(Events.callbacks.resaleSell, data) or { ok = false })
    end)

    RegisterNUICallback('craft', function(data, cb)
        cb(Callback.await(Events.callbacks.craft, data.id) or { ok = false })
    end)

    RegisterNUICallback('classSelect', function(data, cb)
        cb(Callback.await(Events.callbacks.classSelect, data.id) or { ok = false })
    end)

    RegisterNUICallback('nameColorSelect', function(data, cb)
        cb(Callback.await(Events.callbacks.nameColorSelect, data.colors) or { ok = false })
    end)

    RegisterNUICallback('killfeedBackgroundBuy', function(data, cb)
        cb(Callback.await(Events.callbacks.killfeedBackgroundBuy, data.id) or { ok = false })
    end)

    RegisterNUICallback('killfeedBackgroundSelect', function(data, cb)
        cb(Callback.await(Events.callbacks.killfeedBackgroundSelect, data.id) or { ok = false })
    end)

    RegisterNUICallback('tutorialSkip', function(_, cb)
        cb(Callback.await(Events.callbacks.tutorialSkip) or { ok = false })
    end)
    RegisterNUICallback('insuranceBuy', function(data, cb)
        cb(Callback.await(Events.callbacks.insuranceBuy, data.item) or { ok = false })
    end)
    RegisterNUICallback('blackMarketList', function(_, cb)
        cb(Callback.await(Events.callbacks.blackMarketList) or { open = false, stock = {} })
    end)
    RegisterNUICallback('blackMarketBuy', function(data, cb)
        cb(Callback.await(Events.callbacks.blackMarketBuy, data.index, data.quantity) or { ok = false })
    end)
    RegisterNUICallback('seasonPassClaim', function(data, cb)
        cb(Callback.await(Events.callbacks.seasonPassClaim, { tier = data.tier, premium = data.premium == true }) or { ok = false })
    end)
    RegisterNUICallback('seasonPassBuy', function(_, cb)
        cb(Callback.await(Events.callbacks.seasonPassBuy) or { ok = false })
    end)

    RegisterNUICallback('titleSelect', function(data, cb)
        cb(Callback.await(Events.callbacks.titleSelect, data.id) or { ok = false })
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

    -- Prix de la boutique (voir ShopService) : Config.Shop est aussi relu si la page n'est pas encore prête
    RegisterNetEvent(Events.client.shopPrices, function(prices)
        for _, entry in ipairs(Config.Shop) do
            entry.price = prices[entry.item] or entry.price
        end
        Nui.send('shopPrices', prices)
    end)
end

---Les messages à traduire venus du serveur (Locale.t) sont traduits ici, dans la langue du joueur.
---@param action string
---@param data? any
function Nui.send(action, data)
    SendNUIMessage({ action = action, data = Locale.resolve(data) })
end

---@param text string
---@param kind? 'info'|'success'|'error'
function Nui.notify(text, kind)
    Nui.send('notify', { text = text, kind = kind or 'info' })
end

---@return table
function Nui.buildInitPayload()
    return {
        locale = Language.payload(),
        config = {
            shop = Config.Shop,
            shopMaxQuantity = Config.ShopMaxQuantity,
            items = Config.Items,
            containers = Config.Containers,
            shortcutSlots = Config.ShortcutSlots,
            xpPerLevel = Config.XpPerLevel,
            groupMaxSize = Config.Groups.maxSize,
            bountyPlayer = Config.Bounty.player,
            crew = {
                maxMembers = Config.Crews.maxMembers,
                createPrice = Config.Crews.createPrice,
                nameMaxLength = Config.Crews.nameMaxLength,
                maxTerritories = Config.ControlZones.territories.maxPerCrew,
                territoryInterval = Config.ControlZones.territories.incomeInterval,
                stashCapacity = Config.Crews.stash.capacity,
                captureScore = Config.Crews.stats.captureScore,
                war = { minStake = Config.Crews.war.minStake, maxStake = Config.Crews.war.maxStake, duration = Config.Crews.war.duration },
            },
            nameColors = Config.NameColors,
            achievements = Config.Achievements,
            tutorial = { steps = Config.Tutorial.steps, finalReward = Config.Tutorial.finalReward },
            seasonPass = {
                premiumPrice = Config.SeasonPass.premiumPrice,
                pointsPerTier = Config.SeasonPass.pointsPerTier,
                tiers = Config.SeasonPass.tiers,
            },
            seasonRewards = Config.SeasonRewards.ranks,
            seasonRewardsMinKills = Config.SeasonRewards.minKills,
            achievementStats = Config.AchievementStats,
            killfeedBackgrounds = Config.KillfeedBackgrounds,
            menuKey = Config.MenuKeyLabel,
            attachments = Config.Attachments,
            recipes = Config.Recipes,
            classes = { keyLabel = Config.Classes.keyLabel, list = Config.Classes.list },
            cases = Config.Cases,
            caseRarities = Config.CaseRarities,
            shopPoints = {
                label = Config.ShopPoints.label,
                short = Config.ShopPoints.short,
                storeUrl = Config.ShopPoints.storeUrl ~= '' and Config.ShopPoints.storeUrl or nil,
            },
        },
        player = State.player,
        crew = Crew.data,
        territories = Control.territoryList(),
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
    local coords = GetEntityCoords(PlayerPedId())
    -- Services des PNJ de la zone safe à portée (coffre, boutique, fabrication...)
    local near = SafeNpcs.nearRoles(coords)
    if Dungeon.isAtChest(coords) then near.stash = true end
    Nui.send('menu', {
        open = State.menuOpen,
        inSafe = State.isInSafeZone(),
        near = near,
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
    -- En Call of Duty, elle affiche le tableau des scores tant qu'elle est maintenue (voir Cod.updateScoreboard)
    if State.mode == 'cod' then return end
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
