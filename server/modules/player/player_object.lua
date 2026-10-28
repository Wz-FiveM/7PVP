---Joueur connecté. Toutes les modifications d'argent, d'XP et d'inventaire passent par ici.
---L'argent est un objet (`money`) de l'inventaire.
---@class PvpPlayer
---@field source integer
---@field identifier string
---@field name string
---@field xp integer
---@field kills integer
---@field deaths integer
---@field npcKills integer
---@field inventory PvpInventory
---@field ammoSeq integer dernier rapport de munitions traité
---@field appearance table|nil apparence du personnage (nil = pas encore créé)
---@field creating boolean dans le créateur de personnage
---@field mode string|nil mode de jeu en cours ('pvp', 'freeroam'), nil = au lobby
---@field avatar string|nil URL de l'avatar Discord (DiscordAvatar)
---@field isAdmin boolean admin enregistré en base (colonne is_admin, commande setadmin)
---@field dead boolean
---@field combatUntil integer fin du statut « en combat » (GetGameTimer), 0 = hors combat
---@field combatNotifiedAt integer dernier envoi du statut au client
---@field lastAttacker integer|nil server id du dernier joueur qui l'a touché en combat
---@field lastCombatCoords vector3|nil position à la dernière touche (si le ped a disparu à la déconnexion)
---@field contracts table progression des contrats du jour (voir ContractService)
---@field season { id: string, kills: integer, deaths: integer, npcKills: integer }|nil stats de la saison (SeasonService)
---@field streak integer kills de joueurs depuis la dernière mort
---@field bounty integer prime sur sa tête ($), 0 = aucune
---@field combatLog { taken: table<integer, table>, dealt: table<integer, table> } dégâts de la vie en cours, par joueur
local PlayerObject = PVP.define('PlayerObject')
local InventoryObject = PVP.use('InventoryObject')
local AppearanceSchema = PVP.use('AppearanceSchema')
local Items = PVP.use('Items')
local Progression = PVP.use('Progression')
local Zones = PVP.use('Zones')
local ContractService = PVP.use('ContractService')
local SeasonService = PVP.use('SeasonService')
local Events = PVP.use('Events')

PlayerObject.__index = PlayerObject

---@param source integer
---@param identifier string
---@param row table ligne de la table pvp_players
---@return PvpPlayer
function PlayerObject.new(source, identifier, row)
    return setmetatable({
        source = source,
        identifier = identifier,
        name = GetPlayerName(source),
        xp = row.xp,
        kills = row.kills,
        deaths = row.deaths,
        npcKills = row.npc_kills,
        inventory = InventoryObject.decode(row.inventory),
        appearance = AppearanceSchema.decode(row.appearance),
        creating = false,
        mode = nil,
        isAdmin = row.is_admin == 1 or row.is_admin == true,
        ammoSeq = 0,
        -- Armes de jet lancées récemment : [objet] = os.time() (l'anti-cheat accepte leurs dégâts)
        recentThrows = {},
        dead = false,
        combatUntil = 0,
        combatNotifiedAt = 0,
        lastAttacker = nil,
        lastCombatCoords = nil,
        contracts = ContractService.decode(row.contracts),
        streak = 0,
        bounty = 0,
        combatLog = { taken = {}, dealt = {} },
    }, PlayerObject)
end

-- ---------------------------------------------------------------------------
-- Monde
-- ---------------------------------------------------------------------------

function PlayerObject:getPed()
    return GetPlayerPed(self.source)
end

---@return vector3
function PlayerObject:getCoords()
    return GetEntityCoords(self:getPed())
end

function PlayerObject:getZone()
    return Zones.getAt(self:getCoords(), self.mode)
end

---@return boolean
function PlayerObject:isInSafeZone()
    return Zones.isSafe(self:getCoords(), self.mode)
end

-- ---------------------------------------------------------------------------
-- Communication
-- ---------------------------------------------------------------------------

---@param message string
---@param kind? 'info'|'success'|'error'
function PlayerObject:notify(message, kind)
    TriggerClientEvent(Events.client.notify, self.source, message, kind or 'info')
end

function PlayerObject:sync()
    -- Objet rangé au coffre, vendu, jeté ou perdu : il quitte aussi les raccourcis
    self.inventory:pruneShortcuts()
    TriggerClientEvent(Events.client.sync, self.source, self:serialize())
end

---@return table
function PlayerObject:serialize()
    return {
        source = self.source,
        name = self.name,
        avatar = self.avatar,
        money = self:getMoney(),
        xp = self.xp,
        level = self:getLevel(),
        kills = self.kills,
        deaths = self.deaths,
        npcKills = self.npcKills,
        inventory = self.inventory:serialize(),
        ammoSeq = self.ammoSeq,
        streak = self.streak,
        bounty = self.bounty,
        contracts = ContractService.serialize(self),
        season = self.season and {
            label = SeasonService.label(self.season.id),
            kills = self.season.kills,
            deaths = self.season.deaths,
            npcKills = self.season.npcKills,
        } or nil,
    }
end

-- ---------------------------------------------------------------------------
-- Argent / progression
-- ---------------------------------------------------------------------------

---@return integer argent total (sac + conteneur protégé)
function PlayerObject:getMoney()
    return self.inventory:count('money')
end

---L'argent gagné arrive dans le sac.
---@param amount integer
function PlayerObject:addMoney(amount)
    self.inventory:add('bag', 'money', amount)
end

---@param amount integer
---@return boolean
function PlayerObject:removeMoney(amount)
    return self.inventory:remove('money', amount)
end

---Compte un kill, une mort ou un zombie tué, pour toujours et pour la saison.
---@param stat 'kills'|'deaths'|'npcKills'
function PlayerObject:incrementStat(stat)
    self[stat] = self[stat] + 1
    if self.season then self.season[stat] = self.season[stat] + 1 end
end

---@return integer
function PlayerObject:getLevel()
    return Progression.levelFromXp(self.xp)
end

---@param amount integer
function PlayerObject:addXp(amount)
    if amount <= 0 then return end
    local before = self:getLevel()
    self.xp = self.xp + amount
    if self:getLevel() > before then
        self:notify(('Niveau %d atteint !'):format(self:getLevel()), 'success')
    end
end

-- ---------------------------------------------------------------------------
-- Inventaire
-- ---------------------------------------------------------------------------

---@param name string
---@param count integer
---@param container? 'bag'|'protected' (défaut : bag)
---@return integer quantité réellement ajoutée (limitée par le poids)
function PlayerObject:giveItem(name, count, container)
    return self.inventory:add(container or 'bag', name, count)
end

---@param name string
---@param count integer
---@return boolean
function PlayerObject:removeItem(name, count)
    return self.inventory:remove(name, count)
end

---@param name string
---@return integer
function PlayerObject:getItemCount(name)
    return self.inventory:count(name)
end

---Vide le sac et renvoie son contenu (le conteneur protégé est conservé).
---@return table<string, integer>
function PlayerObject:takeBag()
    return self.inventory:takeBag()
end

function PlayerObject:applyRespawnKit()
    self.inventory:setBag(Config.RespawnKit)
end

---Munitions tirées, rapportées par le client. `seq` évite de traiter deux fois un rapport.
---@param seq any
---@param report any table<string, number>
---@return boolean
function PlayerObject:consumeAmmo(seq, report)
    seq = tonumber(seq)
    if not seq or seq <= self.ammoSeq or type(report) ~= 'table' then return false end
    self.ammoSeq = seq

    for name, used in pairs(report) do
        -- Munitions, ou armes de jet (l'objet est sa propre munition)
        local item = Items.get(name)
        local isAmmo = item and (item.type == 'ammo' or (item.throwable and item.ammo == name))
        if isAmmo and type(used) == 'number' and used > 0 then
            self.inventory:remove(name, math.min(math.floor(used), self.inventory:count(name)))
            if item.throwable then self.recentThrows[name] = os.time() end
        end
    end
    return true
end
