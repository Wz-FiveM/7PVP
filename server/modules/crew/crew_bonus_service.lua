---Points de crew (Config.Crews.bonus) : gagnés ensemble (kills, territoires, guerre, tournoi),
---dépensés par le chef ou un officier pour agrandir le coffre, ouvrir l'armurerie et y acheter des armes.
---Les armes achetées vont dans le coffre du crew. Rien d'acheté ne se perd, sauf à la dissolution.
---@class CrewBonusEntry
---@field name string auteur de la dépense
---@field kind 'stash'|'armory'|'weapon'
---@field level? integer niveau atteint (stash, armory)
---@field item? string arme achetée (weapon)
---@field cost integer
---@field at integer os.time()

---@class CrewBonus
---@field points integer
---@field stashLevel integer
---@field armoryLevel integer
---@field lastBuy integer os.time() du dernier achat d'arme
---@field log CrewBonusEntry[] du plus récent au plus ancien

---@class CrewBonusServiceModule
local CrewBonusService = PVP.define('CrewBonusService')
local CrewService = PVP.use('CrewService')
local CrewRepository = PVP.use('CrewRepository')
local CrewStashService = PVP.use('CrewStashService')
local PlayerService = PVP.use('PlayerService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local Logger = PVP.use('Logger')

-- Améliorations achetées par niveaux, dans l'ordre (Config.Crews.bonus)
CrewBonusService.UPGRADES = {
    stash = { levels = 'stashLevels', field = 'stashLevel', label = 'Coffre du crew' },
    armory = { levels = 'armoryLevels', field = 'armoryLevel', label = 'Armurerie du crew' },
}

---@type table<string, CrewBonus> label -> points et achats
CrewBonusService.bonuses = {}

function CrewBonusService.init()
    Callback.register(Events.callbacks.crewUpgrade, CrewBonusService.upgrade)
    Callback.register(Events.callbacks.crewArmoryBuy, CrewBonusService.buyWeapon)
end

---Points et achats gardés en base : appelé par CrewService au chargement des crews.
---@param rows { crew_tag: string, points: any, stash_level: any, armory_level: any, last_buy: any, log: string }[]
function CrewBonusService.restore(rows)
    for _, row in ipairs(rows) do
        local ok, log = pcall(json.decode, row.log)
        CrewBonusService.bonuses[row.crew_tag] = {
            points = tonumber(row.points) or 0,
            stashLevel = math.min(tonumber(row.stash_level) or 0, #Config.Crews.bonus.stashLevels),
            armoryLevel = math.min(tonumber(row.armory_level) or 0, #Config.Crews.bonus.armoryLevels),
            lastBuy = tonumber(row.last_buy) or 0,
            log = ok and type(log) == 'table' and log or {},
        }
    end
end

---@param tag string
---@return CrewBonus
function CrewBonusService.get(tag)
    local bonus = CrewBonusService.bonuses[tag]
    if not bonus then
        bonus = { points = 0, stashLevel = 0, armoryLevel = 0, lastBuy = 0, log = {} }
        CrewBonusService.bonuses[tag] = bonus
    end
    return bonus
end

---Crew dissous (la base est nettoyée par CrewRepository.delete).
---@param tag string
function CrewBonusService.remove(tag)
    CrewBonusService.bonuses[tag] = nil
end

---@param tag string
---@return number capacité du coffre en kg, agrandissements compris
function CrewBonusService.stashCapacity(tag)
    local bonus = CrewBonusService.bonuses[tag]
    local level = bonus and Config.Crews.bonus.stashLevels[bonus.stashLevel]
    return Config.Crews.stash.capacity * (1 + (level and level.bonus or 0) / 100)
end

---@param tag string
---@return table envoyé aux membres avec le crew (CrewService.serialize)
function CrewBonusService.describe(tag)
    local bonus = CrewBonusService.get(tag)
    return {
        points = bonus.points,
        stashLevel = bonus.stashLevel,
        armoryLevel = bonus.armoryLevel,
        buyIn = math.max(0, bonus.lastBuy + Config.Crews.bonus.buyCooldown - os.time()),
        log = bonus.log,
    }
end

---Ajoute des points au crew. Sans effet si le crew n'existe plus.
---@param tag string|nil
---@param reason 'kill'|'capture'|'territory'|'warWin'|'tournamentWin' (Config.Crews.bonus.earn)
function CrewBonusService.earn(tag, reason)
    local crew = tag and CrewService.crews[tag]
    local amount = Config.Crews.bonus.earn[reason] or 0
    if not crew or amount <= 0 then return end

    local bonus = CrewBonusService.get(tag)
    bonus.points = bonus.points + amount
    CrewRepository.saveBonus(tag, bonus)
    CrewService.sync(crew)
end

---@param source integer
---@return PvpPlayer|nil, PvpCrew|nil, table|nil raison du refus (Locale.t)
function CrewBonusService.spender(source)
    local player = PlayerService.get(source)
    if not player then return nil end
    if player.mode ~= 'pvp' then return nil, nil, Locale.t('Disponible seulement en PvP.') end
    local crew = CrewService.crewOf(source)
    if not crew then return nil, nil, Locale.t('Tu n\'es dans aucun crew.') end
    if not CrewService.canManage(crew, player.identifier) then
        return nil, nil, Locale.t('Seuls le chef et les officiers dépensent les points du crew.')
    end
    return player, crew
end

---@param bonus CrewBonus
---@param player PvpPlayer
---@param entry CrewBonusEntry sans name ni at
function CrewBonusService.spend(bonus, player, entry)
    bonus.points = bonus.points - entry.cost
    entry.name = player.name
    entry.at = os.time()
    table.insert(bonus.log, 1, entry)
    while #bonus.log > Config.Crews.bonus.logSize do table.remove(bonus.log) end
end

---Achète le niveau suivant d'une amélioration (coffre ou armurerie).
---@param source integer
---@param kind any 'stash' ou 'armory'
---@return { ok: boolean, message?: string }
function CrewBonusService.upgrade(source, kind)
    local player, crew, denied = CrewBonusService.spender(source)
    if not player then return { ok = false, message = denied } end
    local upgrade = CrewBonusService.UPGRADES[kind]
    if not upgrade then return { ok = false } end

    local bonus = CrewBonusService.get(crew.tag)
    local levels = Config.Crews.bonus[upgrade.levels]
    local level = bonus[upgrade.field] + 1
    local wanted = levels[level]
    if not wanted then return { ok = false, message = Locale.t('Niveau maximum atteint.') } end
    if bonus.points < wanted.cost then
        return { ok = false, message = Locale.t('Il manque %d points de crew.', wanted.cost - bonus.points) }
    end

    bonus[upgrade.field] = level
    CrewBonusService.spend(bonus, player, { kind = kind, level = level, cost = wanted.cost })
    CrewRepository.saveBonus(crew.tag, bonus)
    CrewService.notifyMembers(crew, Locale.t('%s : niveau %d acheté par %s.', Locale.t(upgrade.label), level, player.name))
    CrewService.sync(crew)
    Logger.info('[crew] %s achète %s niveau %d pour [%s] (%d points)', player.name, kind, level, crew.tag, wanted.cost)
    return { ok = true }
end

---@param item any
---@return table|nil arme de Config.Crews.bonus.weapons
function CrewBonusService.findWeapon(item)
    for _, weapon in ipairs(Config.Crews.bonus.weapons) do
        if weapon.item == item then return weapon end
    end
    return nil
end

---Achète une arme de l'armurerie : elle arrive dans le coffre du crew.
---@param source integer
---@param item any
---@return { ok: boolean, message?: string }
function CrewBonusService.buyWeapon(source, item)
    local player, crew, denied = CrewBonusService.spender(source)
    if not player then return { ok = false, message = denied } end
    local weapon = CrewBonusService.findWeapon(item)
    if not weapon or not Items.exists(weapon.item) then return { ok = false } end

    local bonus = CrewBonusService.get(crew.tag)
    local settings = Config.Crews.bonus
    if bonus.armoryLevel < weapon.tier then
        return { ok = false, message = Locale.t('Il faut l\'armurerie niveau %d.', weapon.tier) }
    end
    local wait = bonus.lastBuy + settings.buyCooldown - os.time()
    if wait > 0 then
        return { ok = false, message = Locale.t('Prochain achat d\'arme dans %d min.', math.ceil(wait / 60)) }
    end
    if bonus.points < weapon.cost then
        return { ok = false, message = Locale.t('Il manque %d points de crew.', weapon.cost - bonus.points) }
    end

    local stash = CrewStashService.get(crew.tag)
    if (stash.items[weapon.item] or 0) >= settings.stockLimit then
        return { ok = false, message = Locale.t('Le coffre a déjà %d exemplaires de cette arme.', settings.stockLimit) }
    end
    if CrewStashService.maxFit(crew.tag, weapon.item) < 1 then
        return { ok = false, message = Locale.t('Pas assez de place dans : %s.', Locale.t('Coffre du crew')) }
    end

    bonus.lastBuy = os.time()
    CrewBonusService.spend(bonus, player, { kind = 'weapon', item = weapon.item, cost = weapon.cost })
    CrewRepository.saveBonus(crew.tag, bonus)
    CrewStashService.addItem(crew.tag, weapon.item, 1, 'Armurerie du crew')
    CrewService.sync(crew)
    Logger.info('[crew] %s achète %s pour [%s] (%d points)', player.name, weapon.item, crew.tag, weapon.cost)
    return { ok = true, message = Locale.t('%s ajouté au coffre du crew.', Locale.t(Items.get(weapon.item).label)) }
end
