---Joueur connecté. Toutes les modifications d'argent, d'XP et d'inventaire passent par ici.
---L'argent est un objet (`money`) de l'inventaire.
---@class PvpPlayer
---@field source integer
---@field identifier string
---@field charId integer character id, unique et permanent (Config.CharacterId)
---@field name string
---@field xp integer
---@field kills integer
---@field deaths integer
---@field npcKills integer
---@field assists integer assistances (Config.Assists)
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
---@field shopPoints integer|nil copie du solde de points boutique (ShopPointsService, la base fait foi)
---@field streak integer kills de joueurs depuis la dernière mort
---@field bounty integer prime sur sa tête ($), 0 = aucune
---@field combatLog { taken: table<integer, table>, dealt: table<integer, table> } dégâts de la vie en cours, par joueur
---@field classId string|nil classe du mode PvP (Config.Classes)
---@field nameColor string|nil couleurs du nom en PvP, un code par lettre (voir NameColors)
---@field killfeedBackground string|nil fond choisi pour ses lignes du killfeed (KillfeedBackgroundService)
---@field killfeedOwned table<string, boolean> fonds du killfeed achetés
---@field killMessage string|nil texte montré à ses victimes (KillMessageService)
---@field killMessageOwned boolean droit au message de kill acheté
---@field loadoutSets (table<string, integer>|false)[] sets d'équipement (LoadoutSetService)
---@field achievements PvpAchievements hauts faits et titre choisi (AchievementService)
---@field seasonTitles table<string, string>|nil titres de saison possédés : id -> texte (SeasonRewardService)
---@field seasonPass PvpSeasonPass|nil passe de saison (SeasonPassService)
---@field insurance table<string, boolean>|nil armes assurées (InsuranceService)
---@field downed PvpDowned|nil à terre (DownedService)
---@field downedAt integer|nil os.time() de la dernière fois à terre
---@field tutorial PvpTutorial premiers pas (TutorialService)
local PlayerObject = PVP.define('PlayerObject')
local InventoryObject = PVP.use('InventoryObject')
local AppearanceSchema = PVP.use('AppearanceSchema')
local Items = PVP.use('Items')
local Progression = PVP.use('Progression')
local Zones = PVP.use('Zones')
local ContractService = PVP.use('ContractService')
local SeasonService = PVP.use('SeasonService')
local ClassService = PVP.use('ClassService')
local CrewService = PVP.use('CrewService')
local NameColors = PVP.use('NameColors')
local KillfeedBackgroundService = PVP.use('KillfeedBackgroundService')
local LoadoutSetService = PVP.use('LoadoutSetService')
local RivalryService = PVP.use('RivalryService')
local BountyService = PVP.use('BountyService')
local AchievementService = PVP.use('AchievementService')
local SeasonPassService = PVP.use('SeasonPassService')
local InsuranceService = PVP.use('InsuranceService')
local TutorialService = PVP.use('TutorialService')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

PlayerObject.__index = PlayerObject

---@param source integer
---@param identifier string
---@param row table ligne de la table pvp_players
---@return PvpPlayer
function PlayerObject.new(source, identifier, row)
    local player = setmetatable({
        source = source,
        identifier = identifier,
        charId = math.tointeger(row.char_id),
        name = GetPlayerName(source),
        xp = row.xp,
        kills = row.kills,
        deaths = row.deaths,
        npcKills = row.npc_kills,
        assists = row.assists or 0,
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
        classId = ClassService.sanitize(row.class_id),
        nameColor = NameColors.sanitize(row.name_color),
        killfeedOwned = {},
        loadoutSets = LoadoutSetService.decode(row.loadout_sets),
        tutorial = TutorialService.decode(row.tutorial, row),
        achievements = AchievementService.decode(row.achievements, row),
    }, PlayerObject)
    ClassService.applyInventory(player)
    return player
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

---Nom montré aux autres joueurs : avec le label du crew en PvP (« [MGZ] Nom »), le nom seul ailleurs.
---@return string
function PlayerObject:displayName()
    if self.mode ~= 'pvp' then return self.name end
    return CrewService.label(self.identifier, self.name)
end

---Les codes sont alignés sur displayName() : le label du crew reste sans couleur.
---@return string|nil couleurs des lettres de displayName(), nil = aucune
function PlayerObject:displayColors()
    if not self.nameColor then return nil end
    return NameColors.NONE:rep(#self:displayName() - #self.name) .. self.nameColor
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
        charId = self.charId,
        name = self.name,
        displayName = CrewService.label(self.identifier, self.name),
        nameColor = self.nameColor,
        killfeedBackground = self.killfeedBackground,
        killfeedOwned = KillfeedBackgroundService.ownedList(self),
        killMessage = self.killMessage,
        killMessageOwned = self.killMessageOwned,
        avatar = self.avatar,
        money = self:getMoney(),
        shopPoints = self.shopPoints or 0,
        xp = self.xp,
        level = self:getLevel(),
        kills = self.kills,
        deaths = self.deaths,
        npcKills = self.npcKills,
        assists = self.assists,
        nemeses = RivalryService.nemeses(self),
        inventory = self.inventory:serialize(),
        bagCapacity = self.inventory:getCapacity('bag'),
        playerClass = ClassService.describe(self),
        ammoSeq = self.ammoSeq,
        streak = self.streak,
        bounty = self.bounty + BountyService.placedOn(self),
        contracts = ContractService.serialize(self),
        loadoutSets = self.loadoutSets,
        achievements = AchievementService.serialize(self),
        title = AchievementService.titleOf(self),
        seasonPass = SeasonPassService.serialize(self),
        insurance = InsuranceService.serialize(self),
        tutorial = self.tutorial,
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
        self:notify(Locale.t('Niveau %d atteint !', self:getLevel()), 'success')
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

---Boîtes de munitions utilisées (un rechargement chacune) et armes de jet lancées, rapportées par
---le client. `seq` évite de traiter deux fois un rapport.
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
