---TEMPORAIRE (Config.AntiCheat.hitJournal) : quand le serveur voit un joueur encaisser des touches sans
---perdre de vie (alerte « Touches sans aucun effet »), il demande à son client ce qui le protège.
---La réponse part dans le journal [touche] du serveur : invincibilité, protections, tir allié, zone, effets.
---@class ProtectionReportModule
local ProtectionReport = PVP.define('ProtectionReport')
local Events = PVP.use('Events')
local State = PVP.use('State')
local Zone = PVP.use('Zone')
local Group = PVP.use('Group')
local Effects = PVP.use('Effects')
local Creator = PVP.use('Creator')
local Downed = PVP.use('Downed')
local Fall = PVP.use('Fall')

function ProtectionReport.init()
    RegisterNetEvent(Events.client.protectionReport, function()
        TriggerServerEvent(Events.server.protectionReport, ProtectionReport.collect())
    end)
end

---@return table
function ProtectionReport.collect()
    local ped = PlayerPedId()
    local _, bullet, fire, explosion, collision, melee = GetEntityProofs(ped)
    local effects = {}
    for id in pairs(Effects.active) do
        if Effects.isActive(id) then effects[#effects + 1] = id end
    end
    return {
        mode = tostring(State.mode),
        activity = tostring(State.activity),
        zone = type(State.zone) == 'table' and tostring(State.zone.type) or tostring(State.zone),
        protected = Zone.protected == true,
        godmode = State.godmode == true,
        noclip = State.noclip == true,
        spectating = State.spectating == true,
        creator = Creator.active == true,
        downed = Downed.active == true,
        fall = Fall.active == true,
        pveWorld = LocalPlayer.state.pveWorld == true,
        group = Group.data and tostring(Group.data.slot) or 'aucun',
        relation = GetPedRelationshipGroupHash(ped),
        playerInvincible = GetPlayerInvincible(PlayerId()),
        canBeDamaged = GetEntityCanBeDamaged(ped),
        proofs = ('balles %s, feu %s, explosion %s, choc %s, mêlée %s'):format(
            tostring(bullet), tostring(fire), tostring(explosion), tostring(collision), tostring(melee)),
        health = GetEntityHealth(ped),
        maxHealth = GetEntityMaxHealth(ped),
        armor = GetPedArmour(ped),
        effects = table.concat(effects, ','),
        vehicle = IsPedInAnyVehicle(ped, false),
    }
end
