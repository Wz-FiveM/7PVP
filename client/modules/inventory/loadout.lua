---Reflète l'inventaire sur le ped : armes possédées et munitions.
---
---Les munitions sont des objets. Chaque objet de munitions correspond à un « pool » GTA
---partagé par les armes de ce calibre. On suit ce pool pour savoir combien de balles
---ont été tirées, puis on l'envoie au serveur par lots numérotés (`seq`). Tant qu'un lot
---n'est pas confirmé par une synchro serveur (`ammoSeq`), on le déduit nous-mêmes.
---@class LoadoutModule
local Loadout = PVP.define('Loadout')
local State = PVP.use('State')
local Items = PVP.use('Items')
local Events = PVP.use('Events')

Loadout.TRACK_INTERVAL = 250
Loadout.FLUSH_INTERVAL = 2000

Loadout.expected = {} -- [objet munitions] = munitions attendues dans le pool GTA
Loadout.ammoWeapon = {} -- [objet munitions] = hash d'une arme possédée de ce calibre
Loadout.pending = {} -- munitions tirées pas encore envoyées
Loadout.batches = {} -- lots envoyés pas encore confirmés : { seq, used }
Loadout.seq = 0
Loadout.lastFlush = 0

function Loadout.init()
    CreateThread(Loadout.trackLoop)
end

---Appelé à chaque synchro serveur.
---@param data table
function Loadout.onSync(data)
    local ack = data.ammoSeq or 0
    local remaining = {}
    for _, batch in ipairs(Loadout.batches) do
        if batch.seq > ack then remaining[#remaining + 1] = batch end
    end
    Loadout.batches = remaining

    if State.isAlive() then
        Loadout.apply()
    end
end

---Munitions tirées dont le serveur n'a pas encore tenu compte.
---@param ammoName string
---@return integer
function Loadout.unconfirmed(ammoName)
    local total = Loadout.pending[ammoName] or 0
    for _, batch in ipairs(Loadout.batches) do
        total = total + (batch.used[ammoName] or 0)
    end
    return total
end

function Loadout.apply()
    -- L'inventaire n'existe qu'en PvP (le Freeroam gère ses propres armes)
    if not State.inPvp() then return end
    local inventory = State.player and State.player.inventory
    if not inventory then return end

    local ped = PlayerPedId()
    Loadout.ammoWeapon = {}

    local attachments = type(inventory.attachments) == 'table' and inventory.attachments or {}
    for name, item in pairs(Config.Items) do
        if item.type == 'weapon' then
            local owned = Items.countOwned(inventory, name) > 0
            Loadout.syncWeapon(ped, item, owned)
            if owned then Loadout.syncAttachments(ped, name, item, attachments[name] or {}) end
        end
    end

    Loadout.expected = {}
    for ammoName, hash in pairs(Loadout.ammoWeapon) do
        local total = math.max(0, Items.countOwned(inventory, ammoName) - Loadout.unconfirmed(ammoName))
        SetPedAmmo(ped, hash, total)
        Loadout.expected[ammoName] = total
    end
end

---@param ped integer
---@param item table entrée de Config.Items de type weapon
---@param owned boolean
function Loadout.syncWeapon(ped, item, owned)
    local hash = GetHashKey(item.weapon)
    local equipped = HasPedGotWeapon(ped, hash, false)

    if owned and not equipped then
        GiveWeaponToPed(ped, hash, 0, false, false)
    elseif not owned and equipped then
        RemoveWeaponFromPed(ped, hash)
    end

    if owned and item.ammo then
        Loadout.ammoWeapon[item.ammo] = hash
    end
end

---Ajoute ou retire les composants GTA selon les accessoires fixés sur l'arme.
---@param ped integer
---@param name string objet de l'arme
---@param item table
---@param fitted table<string, boolean>
function Loadout.syncAttachments(ped, name, item, fitted)
    local hash = GetHashKey(item.weapon)
    for attachment, weapons in pairs(Config.Attachments) do
        local component = weapons[name]
        if component then
            local componentHash = GetHashKey(component)
            local has = HasPedGotWeaponComponent(ped, hash, componentHash)
            if fitted[attachment] and not has then
                GiveWeaponComponentToPed(ped, hash, componentHash)
            elseif not fitted[attachment] and has then
                RemoveWeaponComponentFromPed(ped, hash, componentHash)
            end
        end
    end
end

function Loadout.trackLoop()
    while true do
        Wait(Loadout.TRACK_INTERVAL)
        if State.isAlive() and State.inPvp() then
            Loadout.track()
            if GetGameTimer() - Loadout.lastFlush >= Loadout.FLUSH_INTERVAL then
                Loadout.flush()
            end
        end
    end
end

---Compare le pool GTA avec ce qui est attendu.
function Loadout.track()
    local ped = PlayerPedId()
    for ammoName, expected in pairs(Loadout.expected) do
        local hash = Loadout.ammoWeapon[ammoName]
        local current = GetAmmoInPedWeapon(ped, hash)
        if current < expected then
            Loadout.pending[ammoName] = (Loadout.pending[ammoName] or 0) + (expected - current)
            Loadout.expected[ammoName] = current
        elseif current > expected then
            -- Munitions venues d'ailleurs que l'inventaire : refusées
            SetPedAmmo(ped, hash, expected)
        end
    end
end

---Envoie au serveur les munitions tirées depuis le dernier envoi.
function Loadout.flush()
    Loadout.lastFlush = GetGameTimer()
    if next(Loadout.pending) == nil then return end

    Loadout.seq = Loadout.seq + 1
    Loadout.batches[#Loadout.batches + 1] = { seq = Loadout.seq, used = Loadout.pending }
    TriggerServerEvent(Events.server.ammoUsed, Loadout.seq, Loadout.pending)
    Loadout.pending = {}
end

---À la mort : dernier relevé, envoi, puis arrêt du suivi jusqu'au respawn.
function Loadout.onDeath()
    Loadout.track()
    Loadout.flush()
    Loadout.expected = {}
end
