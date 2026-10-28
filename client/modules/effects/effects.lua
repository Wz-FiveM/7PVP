---Effets à durée des stimulants (Config.Effects) : endurance illimitée, régénération,
---immunité au vomi des zombies. L'interface affiche chaque effet avec son compte à rebours ;
---elle ne reçoit que les changements (début, fin) et décompte elle-même.
---@class EffectsModule
local Effects = PVP.define('Effects')
local State = PVP.use('State')
local Nui = PVP.use('Nui')

Effects.TICK = 250
Effects.REGEN_INTERVAL = 1000

---@type table<string, { endsAt: integer, duration: integer, perSecond: number|nil, nextHeal: integer }>
Effects.active = {}

function Effects.init()
    CreateThread(Effects.loop)
end

---Démarre un effet, ou relance sa durée s'il est déjà actif.
---@param effect { id: string, duration: integer, perSecond?: number }
function Effects.start(effect)
    if type(effect) ~= 'table' or not Config.Effects[effect.id] then return end
    local now = GetGameTimer()
    Effects.active[effect.id] = {
        endsAt = now + effect.duration * 1000,
        duration = effect.duration,
        perSecond = effect.perSecond,
        nextHeal = now + Effects.REGEN_INTERVAL,
    }
    Effects.send()
end

---@param id string
---@return boolean
function Effects.isActive(id)
    local effect = Effects.active[id]
    return effect ~= nil and effect.endsAt > GetGameTimer()
end

function Effects.clear()
    if next(Effects.active) == nil then return end
    Effects.active = {}
    Effects.send()
end

function Effects.loop()
    while true do
        Wait(Effects.TICK)
        if next(Effects.active) ~= nil then
            Effects.update()
        end
    end
end

function Effects.update()
    -- Mort, lobby ou créateur : plus aucun effet
    if State.dead or not State.spawned then return Effects.clear() end

    local now = GetGameTimer()
    local ped = PlayerPedId()
    local expired = false
    for id, effect in pairs(Effects.active) do
        if now >= effect.endsAt then
            Effects.active[id] = nil
            expired = true
        else
            Effects.apply(id, effect, ped, now)
        end
    end
    if expired then Effects.send() end
end

---@param id string
---@param effect table
---@param ped integer
---@param now integer
function Effects.apply(id, effect, ped, now)
    if id == 'stamina' then
        RestorePlayerStamina(PlayerId(), 1.0)
    elseif id == 'regen' and effect.perSecond and now >= effect.nextHeal then
        effect.nextHeal = now + Effects.REGEN_INTERVAL
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + effect.perSecond))
    end
end

---Liste envoyée à l'interface : l'effet qui finit le plus tôt en premier.
function Effects.send()
    local now = GetGameTimer()
    local list = {}
    for id, effect in pairs(Effects.active) do
        local definition = Config.Effects[id]
        list[#list + 1] = {
            id = id,
            label = definition.label,
            short = definition.short,
            icon = definition.icon,
            remaining = math.max(0, math.ceil((effect.endsAt - now) / 1000)),
            duration = effect.duration,
        }
    end
    table.sort(list, function(a, b) return a.remaining < b.remaining end)
    Nui.send('effects', list)
end
