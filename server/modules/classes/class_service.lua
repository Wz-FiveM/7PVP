---Classes du mode PvP (Config.Classes) : choix en zone safe, passifs côté serveur (dégâts des zombies,
---fabrication, sac, soins partagés, vie max permise) et compétences. Le serveur vérifie chaque compétence et envoie ses
---effets aux clients concernés (client/modules/classes/classes.lua). Les délais survivent à une
---reconnexion : ils sont gardés par licence, en mémoire.
---@class ClassServiceModule
local ClassService = PVP.define('ClassService')
local ClassDefs = PVP.use('ClassDefs')
local PlayerService = PVP.use('PlayerService')
local CombatTagService = PVP.use('CombatTagService')
local GroupService = PVP.use('GroupService')
local ModeRegistry = PVP.use('ModeRegistry')
local PveWorldService = PVP.use('PveWorldService')
local AdminService = PVP.use('AdminService')
local Callback = PVP.use('Callback')
local Items = PVP.use('Items')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local TutorialService = PVP.use('TutorialService')

ClassService.MODE = 'pvp'

-- Compétence -> fonction de ce module
ClassService.HANDLERS = {
    roar = 'useRoar',
    antidote = 'useAntidote',
    mark = 'useMark',
    trap = 'useTrap',
    contract = 'useContract',
    smoke = 'useSmoke',
    frenzy = 'useFrenzy',
    blast = 'useBlast',
}
-- Secondes laissées au client pour appliquer la vie max d'une nouvelle classe, avant le contrôle de l'anticheat
ClassService.HEALTH_GRACE = 10

---@type table<string, { ability: integer, change: integer, healthGrace: integer }> licence -> fin des délais (os.time)
ClassService.timers = {}
---@type table<integer, { target: integer, endsAt: integer }> contrats en cours, par chasseur
ClassService.contracts = {}

function ClassService.init()
    Callback.register(Events.callbacks.classSelect, ClassService.select)
    Callback.register(Events.callbacks.classUse, ClassService.use)
    AddEventHandler(Events.internal.playerUnloading, function(source)
        ClassService.contracts[source] = nil
    end)
end

-- ---------------------------------------------------------------------------
-- Lecture
-- ---------------------------------------------------------------------------

---@param id any valeur de la colonne class_id
---@return string|nil id d'une classe connue
function ClassService.sanitize(id)
    return ClassDefs.get(id) and id or nil
end

---@param player PvpPlayer
---@return table|nil
function ClassService.of(player)
    return ClassDefs.get(player.classId)
end

---@param identifier string
---@return { ability: integer, change: integer, healthGrace: integer }
function ClassService.timersOf(identifier)
    local timers = ClassService.timers[identifier]
    if not timers then
        timers = { ability = 0, change = 0, healthGrace = 0 }
        ClassService.timers[identifier] = timers
    end
    return timers
end

---@param player PvpPlayer
---@return integer santé GTA la plus haute permise à ce joueur (anticheat)
function ClassService.healthLimit(player)
    if os.time() < ClassService.timersOf(player.identifier).healthGrace then return ClassDefs.highestHealth end
    return ClassDefs.maxHealth(ClassService.of(player))
end

---@param player PvpPlayer
---@return { id: string|nil, cooldown: integer, changeIn: integer } envoyé au client à chaque synchro
function ClassService.describe(player)
    local timers = ClassService.timersOf(player.identifier)
    local now = os.time()
    return {
        id = player.classId,
        cooldown = math.max(0, timers.ability - now),
        changeIn = math.max(0, timers.change - now),
    }
end

-- ---------------------------------------------------------------------------
-- Passifs
-- ---------------------------------------------------------------------------

---@param player PvpPlayer
function ClassService.applyInventory(player)
    local class = ClassService.of(player)
    player.inventory:setCapacityBonus('bag', class and class.bagBonus or 0)
end

---@param player PvpPlayer cible du zombie
---@param damage integer
---@return integer
function ClassService.zombieDamage(player, damage)
    local class = ClassService.of(player)
    if not class or not class.zombieDamage then return damage end
    return math.max(1, math.floor(damage * class.zombieDamage + 0.5))
end

---@param player PvpPlayer
---@param count integer quantité de la recette
---@return integer quantité réellement demandée
function ClassService.ingredientCost(player, count)
    local class = ClassService.of(player)
    if not class or not class.craftCost then return count end
    return math.ceil(count * class.craftCost - 1e-6)
end

---Soin partagé : le médecin qui se soigne soigne aussi ses coéquipiers proches.
---@param player PvpPlayer
---@param name string objet utilisé
function ClassService.onItemUsed(player, name)
    local class = ClassService.of(player)
    local item = Items.get(name)
    if not class or not class.healShare or not item or not item.heal then return end

    local amount = math.floor(item.heal * class.healShare)
    if amount <= 0 then return end
    for _, id in ipairs(ClassService.allies(player, class.healRadius, false)) do
        TriggerClientEvent(Events.client.classEffect, id, { type = 'heal', amount = amount })
        TriggerClientEvent(Events.client.notify, id, Locale.t('%s te soigne : +%d PV', player.name, amount), 'success')
    end
end

-- ---------------------------------------------------------------------------
-- Choix de la classe
-- ---------------------------------------------------------------------------

---@param source integer
---@param id any
---@return { ok: boolean, message?: string }
function ClassService.select(source, id)
    local player = PlayerService.get(source)
    local class = ClassDefs.get(id)
    if not player or player.mode ~= ClassService.MODE or player.dead or not class then return { ok = false } end
    if player.classId == id then return { ok = false, message = Locale.t('C\'est déjà ta classe.') } end
    if not player:isInSafeZone() then
        return { ok = false, message = Locale.t('Rejoins une zone safe pour changer de classe.') }
    end
    if CombatTagService.isTagged(player) then
        return { ok = false, message = Locale.t('Tu es en combat : attends %d s.', CombatTagService.remaining(player)) }
    end

    local timers = ClassService.timersOf(player.identifier)
    local now = os.time()
    if player.classId and timers.change > now then
        return { ok = false, message = Locale.t('Changement de classe possible dans %d s.', timers.change - now) }
    end

    player.classId = id
    timers.change = now + Config.Classes.changeCooldown
    timers.healthGrace = now + ClassService.HEALTH_GRACE
    ClassService.applyInventory(player)
    player:sync()
    TutorialService.complete(player, 'class')
    return { ok = true, message = Locale.t('Classe choisie : %s', Locale.t(class.label)) }
end

-- ---------------------------------------------------------------------------
-- Compétences
-- ---------------------------------------------------------------------------

---@param source integer
---@param data any données de la compétence (Marquage : point visé)
---@return { ok: boolean, message?: string }
function ClassService.use(source, data)
    local player = PlayerService.get(source)
    if not player or player.mode ~= ClassService.MODE or player.dead then return { ok = false } end

    local class = ClassService.of(player)
    if not class then return { ok = false, message = Locale.t('Choisis d\'abord une classe dans le menu.') } end

    local ability = class.ability
    local timers = ClassService.timersOf(player.identifier)
    local now = os.time()
    if timers.ability > now then
        return { ok = false, message = Locale.t('%s : disponible dans %d s.', Locale.t(ability.label), timers.ability - now) }
    end
    if player:isInSafeZone() then return { ok = false, message = Locale.t('Pas de compétence en zone safe.') } end

    local inside = PveWorldService.isInside(source)
    if ability.world == 'pve' and not inside then
        return { ok = false, message = Locale.t('%s : ne sert qu\'en zone zombies.', Locale.t(ability.label)) }
    end
    if ability.world == 'pvp' and inside then
        return { ok = false, message = Locale.t('%s : ne sert pas en zone zombies.', Locale.t(ability.label)) }
    end

    local ok, message = ClassService[ClassService.HANDLERS[ability.id]](player, ability, data)
    if not ok then return { ok = false, message = message } end

    timers.ability = now + ability.cooldown
    player:sync()
    return { ok = true, message = message or Locale.t('%s activé', Locale.t(ability.label)) }
end

---@param player PvpPlayer
---@param range number
---@return integer[] joueurs vivants du mode, même monde, à portée (lanceur compris)
function ClassService.nearby(player, range)
    local coords = player:getCoords()
    local bucket = GetPlayerRoutingBucket(player.source)
    local list = {}
    for _, id in ipairs(ModeRegistry.getPlayers(ClassService.MODE)) do
        local other = PlayerService.get(id)
        if other and not other.dead and GetPlayerRoutingBucket(id) == bucket and #(other:getCoords() - coords) <= range then
            list[#list + 1] = id
        end
    end
    return list
end

---@param player PvpPlayer
---@param range number
---@param withSelf boolean
---@return integer[] coéquipiers à portée
function ClassService.allies(player, range, withSelf)
    local list = {}
    for _, id in ipairs(ClassService.nearby(player, range)) do
        if GroupService.areAllies(player.source, id) or (withSelf and id == player.source) then
            list[#list + 1] = id
        end
    end
    return list
end

---Effet visible par tous les joueurs proches, à la position du lanceur.
---@param player PvpPlayer
---@param data table
function ClassService.broadcast(player, data)
    local coords = player:getCoords()
    data.x, data.y, data.z = coords.x, coords.y, coords.z
    for _, id in ipairs(ClassService.nearby(player, Config.Classes.effectRange)) do
        TriggerClientEvent(Events.client.classEffect, id, data)
    end
end

---@param player PvpPlayer
---@param ability table
---@return boolean
function ClassService.useRoar(player, ability)
    ClassService.broadcast(player, { type = 'stun', radius = ability.radius, stun = ability.stun, push = ability.push })
    return true
end

---@param player PvpPlayer
---@param ability table
---@return boolean
function ClassService.useTrap(player, ability)
    ClassService.broadcast(player, { type = 'trap', radius = ability.radius, stun = ability.stun, duration = ability.duration })
    return true
end

---@param player PvpPlayer
---@param ability table
---@return boolean
function ClassService.useSmoke(player, ability)
    ClassService.broadcast(player, { type = 'smoke', particle = ability.particle, duration = ability.duration })
    return true
end

---@param player PvpPlayer
---@param ability table
---@return boolean
function ClassService.useAntidote(player, ability)
    for _, id in ipairs(ClassService.allies(player, ability.radius, true)) do
        TriggerClientEvent(Events.client.classEffect, id, { type = 'antizin', duration = ability.duration })
    end
    return true
end

---@param player PvpPlayer
---@param ability table
---@return boolean
function ClassService.useFrenzy(player, ability)
    TriggerClientEvent(Events.client.classEffect, player.source, { type = 'frenzy', duration = ability.duration, melee = ability.melee })
    return true
end

---Le point visé vient du client : seule sa distance au lanceur est vérifiée.
---@param player PvpPlayer
---@param ability table
---@param data any { x, y, z }
---@return boolean, string|nil
function ClassService.useBlast(player, ability, data)
    local x, y, z = type(data) == 'table' and tonumber(data.x), type(data) == 'table' and tonumber(data.y), type(data) == 'table' and tonumber(data.z)
    if not x or not y or not z then return false, Locale.t('Vise le point à faire exploser.') end

    local distance = #(player:getCoords() - vector3(x, y, z))
    if distance > ability.range + 5.0 then return false, Locale.t('Vise le point à faire exploser.') end
    if distance < ability.minRange then return false, Locale.t('Trop près : vise plus loin.') end

    TriggerClientEvent(Events.client.classEffect, player.source, { type = 'blast', x = x, y = y, z = z, explosion = ability.explosion })
    return true
end

---Le point visé vient du client : seule sa distance au lanceur est vérifiée. Le repère ne va qu'à son équipe.
---@param player PvpPlayer
---@param ability table
---@param data any { x, y, z, netId }
---@return boolean, string|nil
function ClassService.useMark(player, ability, data)
    local x, y, z = type(data) == 'table' and tonumber(data.x), type(data) == 'table' and tonumber(data.y), type(data) == 'table' and tonumber(data.z)
    if not x or not y or not z or #(player:getCoords() - vector3(x, y, z)) > ability.range + 5.0 then
        return false, Locale.t('Vise quelque chose à marquer.')
    end

    local effect = { type = 'mark', x = x, y = y, z = z, netId = tonumber(data.netId), duration = ability.duration, blip = ability.blip }
    local group = GroupService.getGroupOf(player.source)
    for _, id in ipairs(group and group.members or { player.source }) do
        if GetPlayerRoutingBucket(id) == GetPlayerRoutingBucket(player.source) then
            TriggerClientEvent(Events.client.classEffect, id, effect)
        end
    end
    return true
end

---@param player PvpPlayer chasseur
---@param range number
---@return PvpPlayer|nil le joueur le plus recherché à portée, sinon le plus proche
function ClassService.pickContractTarget(player, range)
    local coords = player:getCoords()
    local best, bestBounty, bestDistance = nil, -1, math.huge
    for _, id in ipairs(ModeRegistry.getPlayers(ClassService.MODE)) do
        local other = PlayerService.get(id)
        if other and other ~= player and ClassService.isContractValid(other)
            and not GroupService.areAllies(player.source, id) and not AdminService.isAdmin(id) then
            local distance = #(other:getCoords() - coords)
            local bounty = other.bounty or 0
            if distance <= range and (bounty > bestBounty or (bounty == bestBounty and distance < bestDistance)) then
                best, bestBounty, bestDistance = other, bounty, distance
            end
        end
    end
    return best
end

---@param target PvpPlayer
---@return boolean encore traquable : vivant, en PvP, ni en zone safe ni dans le monde zombies
function ClassService.isContractValid(target)
    return target.mode == ClassService.MODE and not target.dead
        and not PveWorldService.isInside(target.source) and not target:isInSafeZone()
end

---@param player PvpPlayer
---@param ability table
---@return boolean, string|nil
function ClassService.useContract(player, ability)
    local target = ClassService.pickContractTarget(player, ability.range)
    if not target then return false, Locale.t('Aucune cible à portée pour un contrat.') end

    local contract = { target = target.source, endsAt = os.time() + ability.duration }
    ClassService.contracts[player.source] = contract
    target:notify(Locale.t('Un contrat est lancé sur toi : ta position est suivie.'), 'error')
    CreateThread(function()
        ClassService.trackContract(player.source, contract, ability)
    end)
    return true, Locale.t('Contrat lancé sur %s.', target.name)
end

---Envoie au chasseur la position de sa cible, jusqu'à la fin du contrat ou de la traque.
---@param source integer
---@param contract { target: integer, endsAt: integer }
---@param ability table
function ClassService.trackContract(source, contract, ability)
    while ClassService.contracts[source] == contract and os.time() < contract.endsAt do
        local hunter, target = PlayerService.get(source), PlayerService.get(contract.target)
        if not hunter or hunter.dead or hunter.mode ~= ClassService.MODE or not target or not ClassService.isContractValid(target) then break end

        local coords = target:getCoords()
        TriggerClientEvent(Events.client.classEffect, source, {
            type = 'contract', x = coords.x, y = coords.y, z = coords.z, name = target.name, blip = ability.blip,
        })
        Wait(ability.interval * 1000)
    end

    if ClassService.contracts[source] == contract then
        ClassService.contracts[source] = nil
        TriggerClientEvent(Events.client.classEffect, source, { type = 'contractEnd' })
    end
end
