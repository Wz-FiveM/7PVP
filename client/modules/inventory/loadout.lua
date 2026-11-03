---Reflète l'inventaire sur le ped : armes possédées et munitions.
---
---Chaque objet de munitions correspond à un « pool » GTA partagé par les armes de ce calibre.
---Boîtes de munitions (type 'ammo') : une boîte = un chargeur. Le pool ne contient que les balles
---chargées ; recharger (vide, ou touche R) utilise une boîte et remplit le chargeur de l'arme en main
---en entier, les balles qui y restaient sont perdues.
---Armes de jet : l'objet est sa propre munition, le pool vaut le nombre possédé.
---Les objets utilisés partent au serveur par lots numérotés (`seq`). Tant qu'un lot n'est pas
---confirmé par une synchro serveur (`ammoSeq`), on le déduit nous-mêmes.
---@class LoadoutModule
local Loadout = PVP.define('Loadout')
local State = PVP.use('State')
local Items = PVP.use('Items')
local WeaponCustom = PVP.use('WeaponCustom')
local Events = PVP.use('Events')

Loadout.TRACK_INTERVAL = 250
Loadout.FLUSH_INTERVAL = 2000
Loadout.RELOAD_CONTROL = 45 -- INPUT_RELOAD

Loadout.expected = {} -- [objet munitions] = munitions attendues dans le pool GTA (balles chargées pour une boîte)
Loadout.surplus = {} -- [arme de jet] = exemplaires de l'inventaire au-delà du plafond du pool GTA
Loadout.ammoWeapon = {} -- [objet munitions] = hash d'une arme possédée de ce calibre
Loadout.weaponByHash = {} -- [hash] = entrée de Config.Items des armes possédées
Loadout.pending = {} -- objets utilisés pas encore envoyés
Loadout.batches = {} -- lots envoyés pas encore confirmés : { seq, used }
Loadout.seq = 0
Loadout.lastFlush = 0

function Loadout.init()
    CreateThread(Loadout.trackLoop)
    CreateThread(Loadout.reloadLoop)
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

---@param ammoName string
---@return boolean true pour une boîte de munitions (un chargeur), false pour une arme de jet
function Loadout.isMagazine(ammoName)
    return Items.isType(ammoName, 'ammo')
end

---Objets utilisés dont le serveur n'a pas encore tenu compte.
---@param ammoName string
---@return integer
function Loadout.unconfirmed(ammoName)
    local total = Loadout.pending[ammoName] or 0
    for _, batch in ipairs(Loadout.batches) do
        total = total + (batch.used[ammoName] or 0)
    end
    return total
end

---Exemplaires encore utilisables (boîtes ou armes de jet).
---@param ammoName string
---@return integer
function Loadout.available(ammoName)
    local inventory = State.player and State.player.inventory
    if not inventory then return 0 end
    return math.max(0, Items.countUsable(inventory, ammoName) - Loadout.unconfirmed(ammoName))
end

function Loadout.apply()
    -- L'inventaire n'existe qu'en PvP (le Freeroam gère ses propres armes)
    if not State.inPvp() then return end
    local inventory = State.player and State.player.inventory
    if not inventory then return end

    -- Balles tirées depuis le dernier relevé : comptées avant de remettre les pools
    Loadout.track()

    local ped = PlayerPedId()
    Loadout.ammoWeapon = {}
    Loadout.weaponByHash = {}

    for name, item in pairs(Config.Items) do
        if item.type == 'weapon' then
            local owned = Items.countUsable(inventory, name) > 0
            Loadout.syncWeapon(ped, item, owned)
            if owned then WeaponCustom.applyTo(ped, name, item) end
        end
    end

    local expected = {}
    Loadout.surplus = {}
    for ammoName, hash in pairs(Loadout.ammoWeapon) do
        if Loadout.isMagazine(ammoName) then
            -- Les balles chargées restent : seules les boîtes passent par l'inventaire
            SetPedAmmo(ped, hash, Loadout.expected[ammoName] or 0)
            expected[ammoName] = GetAmmoInPedWeapon(ped, hash)
        else
            local total = Loadout.available(ammoName)
            SetPedAmmo(ped, hash, total)
            -- GTA plafonne le pool : le reste attend dans l'inventaire, il ne doit surtout pas être
            -- compté comme lancé. Chaque synchro remplit à nouveau le pool.
            local loaded = math.min(total, GetAmmoInPedWeapon(ped, hash))
            expected[ammoName] = loaded
            Loadout.surplus[ammoName] = total - loaded
        end
    end
    -- Plus aucune arme du calibre : ses balles chargées partent avec elle
    Loadout.expected = expected
end

---Réserve affichée à côté du chargeur : boîtes restantes, ou armes de jet en plus de celle en main.
---@param ammoName string
---@param ped integer
---@param hash integer
---@param clip integer
---@return integer
function Loadout.reserveOf(ammoName, ped, hash, clip)
    if not State.inPvp() then return math.max(0, GetAmmoInPedWeapon(ped, hash) - clip) end
    if Loadout.isMagazine(ammoName) then return Loadout.available(ammoName) end
    return math.max(0, GetAmmoInPedWeapon(ped, hash) - clip) + (Loadout.surplus[ammoName] or 0)
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

    if owned then
        Loadout.weaponByHash[hash] = item
        if item.ammo then Loadout.ammoWeapon[item.ammo] = hash end
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
            -- Balles tirées : rien à rapporter, la boîte a été comptée au rechargement
            if not Loadout.isMagazine(ammoName) then
                Loadout.pending[ammoName] = (Loadout.pending[ammoName] or 0) + (expected - current)
            end
            Loadout.expected[ammoName] = current
        elseif current > expected then
            -- Munitions venues d'ailleurs que l'inventaire : refusées
            SetPedAmmo(ped, hash, expected)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Rechargement à la boîte
-- ---------------------------------------------------------------------------

function Loadout.reloadLoop()
    while true do
        if State.isAlive() and State.inPvp() and Loadout.checkReload() then
            Wait(0)
        else
            Wait(Loadout.TRACK_INTERVAL)
        end
    end
end

---Arme en main à boîtes : recharge quand le pool est vide, ou sur R quand il n'y a plus de réserve.
---@return boolean true tant qu'une arme à boîtes est en main (surveillance à chaque image)
function Loadout.checkReload()
    local ped = PlayerPedId()
    local hash = GetSelectedPedWeapon(ped)
    local item = Loadout.weaponByHash[hash]
    local ammoName = item and item.ammo
    if not ammoName or not Loadout.isMagazine(ammoName) or Loadout.expected[ammoName] == nil then return false end
    if IsPedReloading(ped) or Loadout.available(ammoName) < 1 then return true end

    local pool = GetAmmoInPedWeapon(ped, hash)
    local _, clip = GetAmmoInClip(ped, hash)
    local maxClip = GetMaxAmmoInClip(ped, hash, true)
    if maxClip < 1 then return true end
    -- Des balles du pool hors du chargeur (autre arme du calibre) : GTA recharge avec, sans boîte
    local manual = IsControlJustPressed(0, Loadout.RELOAD_CONTROL) and pool <= clip and clip < maxClip
    if pool == 0 or manual then
        Loadout.reload(ped, hash, ammoName, maxClip)
    end
    return true
end

---Utilise une boîte : chargeur vidé puis rempli en entier, avec l'animation de rechargement.
---@param ped integer
---@param hash integer
---@param ammoName string
---@param maxClip integer
function Loadout.reload(ped, hash, ammoName, maxClip)
    Loadout.track()
    SetAmmoInClip(ped, hash, 0)
    SetPedAmmo(ped, hash, maxClip)
    Loadout.expected[ammoName] = GetAmmoInPedWeapon(ped, hash)
    MakePedReload(ped)

    Loadout.pending[ammoName] = (Loadout.pending[ammoName] or 0) + 1
    Loadout.flush()
end

---Envoie au serveur les objets utilisés depuis le dernier envoi.
function Loadout.flush()
    Loadout.lastFlush = GetGameTimer()
    if next(Loadout.pending) == nil then return end

    Loadout.seq = Loadout.seq + 1
    Loadout.batches[#Loadout.batches + 1] = { seq = Loadout.seq, used = Loadout.pending }
    TriggerServerEvent(Events.server.ammoUsed, Loadout.seq, Loadout.pending)
    Loadout.pending = {}
end

---À la mort : dernier relevé, envoi, puis arrêt du suivi jusqu'au respawn (le chargeur est perdu).
function Loadout.onDeath()
    Loadout.track()
    Loadout.flush()
    Loadout.expected = {}
    Loadout.surplus = {}
end
