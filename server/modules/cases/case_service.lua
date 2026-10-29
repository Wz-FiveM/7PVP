---Caisses (config/cases.lua) : achat chez l'armurier, ouverture, et ouverture payée en points boutique.
---Le tirage est fait ici : le client ne reçoit que la roulette à animer, déjà jouée.
---La récompense est donnée tout de suite (fermer le menu ne l'annule pas), mais l'inventaire
---n'est renvoyé au client qu'à la fin de l'animation, pour ne pas dévoiler le résultat.
---@class CaseServiceModule
local CaseService = PVP.define('CaseService')
local PlayerService = PVP.use('PlayerService')
local CombatTagService = PVP.use('CombatTagService')
local LootService = PVP.use('LootService')
local ChatService = PVP.use('ChatService')
local ShopPointsService = PVP.use('ShopPointsService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local SafeNpcs = PVP.use('SafeNpcs')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')

---@type table<string, table> id -> définition de la caisse
CaseService.byId = {}

function CaseService.init()
    for _, case in ipairs(Config.Cases) do
        CaseService.byId[case.id] = case
        case.totalWeight = 0
        for _, reward in ipairs(case.rewards) do
            if not Items.exists(reward.item) then
                Logger.warn('Caisse "%s" : objet inconnu "%s"', case.id, reward.item)
            end
            if not Config.CaseRarities[reward.rarity] then
                Logger.warn('Caisse "%s" : rareté inconnue "%s"', case.id, tostring(reward.rarity))
            end
            case.totalWeight = case.totalWeight + reward.weight
        end
    end

    Callback.register(Events.callbacks.caseBuy, CaseService.buy)
    Callback.register(Events.callbacks.caseOpen, CaseService.open)
    Callback.register(Events.callbacks.caseOpenPoints, CaseService.openWithPoints)
end

---@param source integer
---@return PvpPlayer|nil
function CaseService.getActivePlayer(source)
    local player = PlayerService.get(source)
    if not player or player.dead or player.mode ~= 'pvp' then return nil end
    return player
end

---@param source integer
---@param id string
---@return { ok: boolean, message: string }
function CaseService.buy(source, id)
    local player = CaseService.getActivePlayer(source)
    local case = CaseService.byId[id]
    if not player or not case or not case.price then
        return { ok = false, message = 'Achat impossible.' }
    end
    if not SafeNpcs.isNear(player:getCoords(), 'shop', Config.SafeNpcs.useDistance + 2.0) then
        return { ok = false, message = SafeNpcs.hint('shop') }
    end
    if player:getLevel() < (case.level or 1) then
        return { ok = false, message = ('Niveau %d requis.'):format(case.level) }
    end
    if player:getMoney() < case.price then
        return { ok = false, message = 'Pas assez d\'argent.' }
    end
    if player.inventory:maxFit('bag', case.id) < 1 then
        return { ok = false, message = 'Ton sac est trop lourd.' }
    end

    player:removeMoney(case.price)
    player:giveItem(case.id, 1)
    player:sync()
    return { ok = true, message = ('Acheté : %s'):format(case.label) }
end

---@param source integer
---@param id string
---@return { ok: boolean, message?: string, reel?: table[], winner?: integer, duration?: number }
function CaseService.open(source, id)
    local player = CaseService.getActivePlayer(source)
    local case = CaseService.byId[id]
    if not player or not case then
        return { ok = false, message = 'Ouverture impossible.' }
    end
    if (player.caseBusyUntil or 0) > GetGameTimer() then
        return { ok = false, message = 'Une caisse est déjà en cours d\'ouverture.' }
    end
    if CombatTagService.isTagged(player) then
        return { ok = false, message = ('En combat : attends %d s.'):format(CombatTagService.remaining(player)) }
    end
    if not player:removeItem(case.id, 1) then
        return { ok = false, message = 'Tu n\'as pas cette caisse.' }
    end
    return CaseService.spin(player, case)
end

---Achat et ouverture immédiate avec des points boutique (la caisse ne passe pas par le sac).
---@param source integer
---@param id string
---@return { ok: boolean, message?: string, reel?: table[], winner?: integer, duration?: number }
function CaseService.openWithPoints(source, id)
    local player = CaseService.getActivePlayer(source)
    local case = CaseService.byId[id]
    if not player or not case or not case.points then
        return { ok = false, message = 'Ouverture impossible.' }
    end
    if (player.caseBusyUntil or 0) > GetGameTimer() then
        return { ok = false, message = 'Une caisse est déjà en cours d\'ouverture.' }
    end
    if player:getLevel() < (case.level or 1) then
        return { ok = false, message = ('Niveau %d requis.'):format(case.level) }
    end
    if CombatTagService.isTagged(player) then
        return { ok = false, message = ('En combat : attends %d s.'):format(CombatTagService.remaining(player)) }
    end

    -- Réservé pendant l'attente de la base : une 2e demande ne peut pas payer en même temps
    player.caseBusyUntil = GetGameTimer() + 10000
    if not ShopPointsService.spend(player, case.points, 'case:' .. case.id) then
        player.caseBusyUntil = 0
        player:sync() -- solde relu en base : l'affichage était peut-être en retard
        return { ok = false, message = ('Pas assez de %s.'):format(Config.ShopPoints.label:lower()) }
    end
    -- Déconnecté pendant le paiement : profil déjà sauvegardé, la récompense serait perdue
    if PlayerService.get(source) ~= player then
        ShopPointsService.credit(player.identifier, case.points, 'refund:' .. case.id)
        return { ok = false }
    end
    return CaseService.spin(player, case)
end

---Tire la récompense, la donne et renvoie la roulette à animer.
---@param player PvpPlayer
---@param case table
---@return { ok: boolean, reel: table[], winner: integer, duration: number }
function CaseService.spin(player, case)
    local source = player.source
    local reward = CaseService.roll(case)
    local count = CaseService.rollCount(reward)
    local options = Config.CaseOptions
    local durationMs = math.floor(options.spinDuration * 1000)
    player.caseBusyUntil = GetGameTimer() + durationMs

    local placed = CaseService.deliver(player, reward.item, count)
    Logger.info('[caisse] %s ouvre %s : %s x%d (%s)', player.name, case.id, reward.item, count, reward.rarity)

    -- Résultat dévoilé à la fin de la roulette
    SetTimeout(durationMs, function()
        local current = PlayerService.get(source)
        if current ~= player then return end
        player:sync()
        player:notify(CaseService.describeDelivery(reward.item, count, placed), 'success')
        if options.announceRarities[reward.rarity] then
            ChatService.announce('pvp', ('%s a obtenu %s (%s) dans une %s !'):format(
                player.name, Items.describe({ [reward.item] = count }), Config.CaseRarities[reward.rarity].label, case.label
            ))
        end
    end)

    return {
        ok = true,
        reel = CaseService.buildReel(case, reward, count),
        winner = options.winnerSlot,
        duration = options.spinDuration,
    }
end

---Tirage pondéré d'une récompense.
---@param case table
---@return table
function CaseService.roll(case)
    local target = math.random() * case.totalWeight
    for _, reward in ipairs(case.rewards) do
        target = target - reward.weight
        if target < 0 then return reward end
    end
    return case.rewards[#case.rewards]
end

---@param reward table
---@return integer
function CaseService.rollCount(reward)
    if type(reward.count) == 'table' then return math.random(reward.count[1], reward.count[2]) end
    return reward.count or 1
end

---Roulette affichée : récompenses tirées au hasard (mêmes chances), la vraie à `winnerSlot`.
---@param case table
---@param reward table
---@param count integer
---@return { item: string, count: integer, rarity: string }[]
function CaseService.buildReel(case, reward, count)
    local reel = {}
    for slot = 1, Config.CaseOptions.reelLength do
        if slot == Config.CaseOptions.winnerSlot then
            reel[slot] = { item = reward.item, count = count, rarity = reward.rarity }
        else
            local filler = CaseService.roll(case)
            reel[slot] = { item = filler.item, count = CaseService.rollCount(filler), rarity = filler.rarity }
        end
    end
    return reel
end

---Range la récompense : sac, puis coffre s'il est plein, puis au sol en dernier recours.
---@param player PvpPlayer
---@param name string
---@param count integer
---@return { bag: integer, stash: integer, ground: integer }
function CaseService.deliver(player, name, count)
    local inBag = player:giveItem(name, count, 'bag')
    local inStash = player:giveItem(name, count - inBag, 'stash')
    local rest = count - inBag - inStash
    if rest > 0 then LootService.drop(player:getCoords(), { [name] = rest }) end
    return { bag = inBag, stash = inStash, ground = rest }
end

---@param name string
---@param count integer
---@param placed { bag: integer, stash: integer, ground: integer }
---@return string
function CaseService.describeDelivery(name, count, placed)
    local message = ('Caisse : %s'):format(Items.describe({ [name] = count }))
    if placed.stash > 0 then message = message .. ' (sac plein : envoyé au coffre)' end
    if placed.ground > 0 then message = message .. ' (sac et coffre pleins : posé au sol)' end
    return message
end
