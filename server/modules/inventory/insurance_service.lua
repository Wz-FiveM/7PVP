---Assurance du sac (Config.Insurance). Une arme assurée se trouvant dans le sac à la mort est notée sur le
---butin ; si elle y est encore quand le butin disparaît, elle revient au coffre, même hors ligne (table
---pvp_insurance_claims). Un redémarrage du serveur efface les butins au sol, et avec eux ce retour.
---@class InsuranceServiceModule
local InsuranceService = PVP.define('InsuranceService')
local InventoryService = PVP.use('InventoryService')
local PlayerRepository = PVP.use('PlayerRepository')
local ShopPointsService = PVP.use('ShopPointsService')
local ResaleService = PVP.use('ResaleService')
local SafeNpcs = PVP.use('SafeNpcs')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Logger = PVP.use('Logger')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

InsuranceService.SCHEMAS = {
    [[CREATE TABLE IF NOT EXISTS pvp_insurance (
        identifier VARCHAR(64) NOT NULL,
        item VARCHAR(64) NOT NULL,
        PRIMARY KEY (identifier, item)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS pvp_insurance_claims (
        id INT NOT NULL AUTO_INCREMENT,
        identifier VARCHAR(64) NOT NULL,
        item VARCHAR(64) NOT NULL,
        PRIMARY KEY (id),
        KEY idx_insurance_claims (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

function InsuranceService.init()
    MySQL.ready(function()
        for _, schema in ipairs(InsuranceService.SCHEMAS) do MySQL.query.await(schema) end
    end)
    Callback.register(Events.callbacks.insuranceBuy, InsuranceService.buy)
end

---Assurances et armes revenues pendant l'absence, au chargement du profil.
---@param player PvpPlayer
function InsuranceService.load(player)
    player.insurance = {}
    for _, row in ipairs(MySQL.query.await('SELECT item FROM pvp_insurance WHERE identifier = ?', { player.identifier }) or {}) do
        player.insurance[row.item] = true
    end

    local delivered = false
    for _, row in ipairs(MySQL.query.await('SELECT id, item FROM pvp_insurance_claims WHERE identifier = ?', { player.identifier }) or {}) do
        if InsuranceService.toStash(player, row.item) then
            MySQL.update('DELETE FROM pvp_insurance_claims WHERE id = ?', { row.id })
            delivered = true
        end
    end
    if delivered then PlayerRepository.save(player) end
end

---@param item string
---@return integer
function InsuranceService.price(item)
    local settings = Config.Insurance
    return math.max(settings.minPrice, math.floor((ResaleService.prices[item] or 0) * 2 * settings.rate))
end

---@param source integer
---@param item any
---@return { ok: boolean, message?: string }
function InsuranceService.buy(source, item)
    local player = InventoryService.getActivePlayer(source)
    if not player or player.dead then return { ok = false, message = Locale.t('Action impossible.') } end
    if not InventoryService.isAtBanker(player) then return { ok = false, message = SafeNpcs.hint('stash') } end

    local definition = type(item) == 'string' and Items.get(item)
    if not definition or definition.type ~= 'weapon' then return { ok = false, message = Locale.t('Seules les armes s\'assurent.') } end
    if player.insurance[item] then return { ok = false, message = Locale.t('Cette arme est déjà assurée.') } end

    local count = 0
    for _ in pairs(player.insurance) do count = count + 1 end
    if count >= Config.Insurance.maxPolicies then
        return { ok = false, message = Locale.t('%d armes assurées au maximum.', Config.Insurance.maxPolicies) }
    end

    local price = InsuranceService.price(item)
    if player:getMoney() < price then return { ok = false, message = Locale.t('Pas assez d\'argent.') } end

    player:removeMoney(price)
    player.insurance[item] = true
    MySQL.insert('INSERT IGNORE INTO pvp_insurance (identifier, item) VALUES (?, ?)', { player.identifier, item })
    PlayerRepository.save(player)
    player:sync()
    Logger.info('[assurance] %s assure %s pour $%d', player.name, item, price)
    return { ok = true, message = Locale.t('%s assuré pour $%d.', Items.label(item), price) }
end

---Mort : les assurances des armes du sac sont consommées.
---@param victim PvpPlayer
---@param items table<string, integer> contenu du sac
---@return { identifier: string, items: table<string, boolean> }|nil à noter sur le butin
function InsuranceService.onDeath(victim, items)
    local covered = {}
    for item in pairs(victim.insurance or {}) do
        if (items[item] or 0) > 0 then
            covered[item] = true
            victim.insurance[item] = nil
            MySQL.update('DELETE FROM pvp_insurance WHERE identifier = ? AND item = ?', { victim.identifier, item })
        end
    end
    if next(covered) == nil then return nil end
    victim:notify(Locale.t('Arme assurée : elle revient au coffre si personne ne la prend sur ton butin.'), 'info')
    return { identifier = victim.identifier, items = covered }
end

---Le butin disparaît : ce qui reste des armes assurées revient à leur propriétaire.
---@param bag LootBag
function InsuranceService.onBagGone(bag)
    for item in pairs(bag.insured.items) do
        if (bag.items[item] or 0) > 0 then InsuranceService.giveBack(bag.insured.identifier, item) end
    end
end

---@param identifier string
---@param item string
function InsuranceService.giveBack(identifier, item)
    local player = ShopPointsService.findOnline(identifier)
    if player and InsuranceService.toStash(player, item) then
        PlayerRepository.save(player)
        player:notify(Locale.t('Ton assurance a rendu : %s (dans ton coffre).', Items.label(item)), 'success')
        player:sync()
    else
        -- Hors ligne, ou coffres pleins : gardé pour son prochain chargement
        MySQL.insert('INSERT INTO pvp_insurance_claims (identifier, item) VALUES (?, ?)', { identifier, item })
    end
    Logger.info('[assurance] %s revient à %s', item, identifier)
end

---@param player PvpPlayer
---@param item string
---@return boolean true si l'arme a trouvé sa place dans un coffre
function InsuranceService.toStash(player, item)
    for _, id in ipairs(player.inventory:openStashes()) do
        if player.inventory:add(id, item, 1) == 1 then return true end
    end
    return false
end

---@param player PvpPlayer
---@return table pour la section Assurance : armes assurées, et prix des armes portées ou au coffre
function InsuranceService.serialize(player)
    local policies = {}
    for item in pairs(player.insurance or {}) do policies[#policies + 1] = item end
    table.sort(policies)

    local prices = {}
    local function scan(items)
        for name in pairs(items or {}) do
            local definition = Items.get(name)
            if definition and definition.type == 'weapon' and not player.insurance[name] then
                prices[name] = InsuranceService.price(name)
            end
        end
    end
    if player.insurance then
        scan(player.inventory.bag)
        for _, id in ipairs(player.inventory:openStashes()) do scan(player.inventory[id]) end
    end
    return { policies = policies, prices = prices, max = Config.Insurance.maxPolicies }
end
