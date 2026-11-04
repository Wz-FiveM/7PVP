---Codes de tenue : un joueur crée le code de la tenue affichée dans son créateur (6 caractères),
---un autre l'entre pour l'essayer sur son personnage puis l'enregistrer chez le vendeur de vêtements.
---Une même tenue garde toujours le même code (clé unique sur la tenue écrite en texte), et seuls
---les vêtements et accessoires passent : visage, cheveux et sexe ne bougent pas.
---@class OutfitCodeServiceModule
local OutfitCodeService = PVP.define('OutfitCodeService')
local PlayerService = PVP.use('PlayerService')
local AppearanceSchema = PVP.use('AppearanceSchema')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')
local Logger = PVP.use('Logger')

OutfitCodeService.SCHEMA = [[CREATE TABLE IF NOT EXISTS pvp_outfit_codes (
    code CHAR(6) NOT NULL,
    signature VARCHAR(191) NOT NULL,
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    uses INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (code),
    UNIQUE KEY uniq_signature (signature)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- Sans I, O, 0 ni 1 : un code se lit et se recopie sans confusion
OutfitCodeService.ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
OutfitCodeService.LENGTH = 6
OutfitCodeService.MAX_TRIES = 8
OutfitCodeService.COOLDOWN = 1000 -- ms entre deux demandes d'un même joueur

OutfitCodeService.ready = false
---@type table<integer, integer> dernière demande (GetGameTimer) par joueur
OutfitCodeService.lastRequest = {}

function OutfitCodeService.init()
    MySQL.ready(function()
        MySQL.query.await(OutfitCodeService.SCHEMA)
        OutfitCodeService.ready = true
    end)

    Callback.register(Events.callbacks.outfitCodeCreate, OutfitCodeService.create)
    Callback.register(Events.callbacks.outfitCodeUse, OutfitCodeService.use)

    AddEventHandler('playerDropped', function()
        OutfitCodeService.lastRequest[source] = nil
    end)
end

---@param source integer
---@return boolean false si le joueur redemande trop vite
function OutfitCodeService.allow(source)
    local now = GetGameTimer()
    local last = OutfitCodeService.lastRequest[source]
    if last and now - last < OutfitCodeService.COOLDOWN then return false end
    OutfitCodeService.lastRequest[source] = now
    return true
end

---@return string
function OutfitCodeService.randomCode()
    local alphabet = OutfitCodeService.ALPHABET
    local chars = {}
    for i = 1, OutfitCodeService.LENGTH do
        local index = math.random(1, #alphabet)
        chars[i] = alphabet:sub(index, index)
    end
    return table.concat(chars)
end

---Code tapé par le joueur : majuscules, sans espaces ni tirets.
---@param raw any
---@return string|nil
function OutfitCodeService.normalize(raw)
    if type(raw) ~= 'string' then return nil end
    local code = raw:upper():gsub('[^%w]', '')
    if #code ~= OutfitCodeService.LENGTH or code:find('[^' .. OutfitCodeService.ALPHABET .. ']') then return nil end
    return code
end

---@param source integer
---@param data table apparence affichée dans le créateur
---@return { ok: boolean, code?: string, message?: string }
function OutfitCodeService.create(source, data)
    local player = PlayerService.get(source)
    if not player or not OutfitCodeService.ready then return { ok = false, message = Locale.t('Le serveur ne répond pas.') } end
    if not OutfitCodeService.allow(source) then return { ok = false, message = Locale.t('Patiente un instant.') } end

    local appearance = AppearanceSchema.sanitize(data)
    if not appearance then return { ok = false, message = Locale.t('Apparence invalide.') } end
    local signature = AppearanceSchema.outfitSignature(appearance)

    local existing = MySQL.scalar.await('SELECT code FROM pvp_outfit_codes WHERE signature = ?', { signature })
    if existing then return { ok = true, code = existing } end

    for _ = 1, OutfitCodeService.MAX_TRIES do
        local code = OutfitCodeService.randomCode()
        local inserted = MySQL.update.await(
            'INSERT IGNORE INTO pvp_outfit_codes (code, signature, created_by) VALUES (?, ?, ?)',
            { code, signature, player.identifier })
        if inserted and inserted > 0 then return { ok = true, code = code } end

        -- Refus : code déjà pris, ou la même tenue enregistrée au même moment par un autre joueur
        existing = MySQL.scalar.await('SELECT code FROM pvp_outfit_codes WHERE signature = ?', { signature })
        if existing then return { ok = true, code = existing } end
    end

    Logger.warn('Code de tenue introuvable après %d essais', OutfitCodeService.MAX_TRIES)
    return { ok = false, message = Locale.t('Réessaie dans un instant.') }
end

---@param source integer
---@param raw any code tapé par le joueur
---@return { ok: boolean, outfit?: table, message?: string }
function OutfitCodeService.use(source, raw)
    if not PlayerService.get(source) or not OutfitCodeService.ready then
        return { ok = false, message = Locale.t('Le serveur ne répond pas.') }
    end
    if not OutfitCodeService.allow(source) then return { ok = false, message = Locale.t('Patiente un instant.') } end

    local code = OutfitCodeService.normalize(raw)
    if not code then return { ok = false, message = Locale.t('Aucune tenue avec ce code.') } end

    local signature = MySQL.scalar.await('SELECT signature FROM pvp_outfit_codes WHERE code = ?', { code })
    local outfit = signature and AppearanceSchema.parseOutfit(signature)
    if not outfit then return { ok = false, message = Locale.t('Aucune tenue avec ce code.') } end

    MySQL.update('UPDATE pvp_outfit_codes SET uses = uses + 1 WHERE code = ?', { code })
    return { ok = true, outfit = outfit }
end
