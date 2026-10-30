---Modes de jeu du Freeroam (Config.FreeroamActivities) : fenêtre ouverte en parlant à leur PNJ
---dans la zone safe, lancement vérifié par le serveur (server/modules/activities).
---@class ActivitiesModule
local Activities = PVP.define('Activities')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Chase = PVP.use('Chase')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')
local Locale = PVP.use('Locale')

Activities.isOpen = false

function Activities.init()
    RegisterNUICallback('activityClose', function(_, cb)
        Activities.close()
        cb({})
    end)
    RegisterNUICallback('activityStart', function(data, cb)
        local result = Callback.await(Events.callbacks.activityStart, type(data) == 'table' and data.id or nil)
            or { ok = false, message = Locale.t('Le serveur ne répond pas.') }
        -- Partie lancée tout de suite (2e joueur de la file) : le vote de la course a déjà pris
        -- le curseur, on ferme la fenêtre sans le lui retirer (les autres modes n'en ont pas besoin)
        if result.ok then Activities.close(Chase.voting) end
        if result.message then Nui.notify(result.message, result.ok and 'success' or 'error') end
        cb(result)
    end)
end

---@param id string clé de Config.FreeroamActivities
function Activities.open(id)
    local activity = Config.FreeroamActivities[id]
    if not activity or Activities.isOpen or IsNuiFocused() or not State.isAlive() then return end

    Activities.isOpen = true
    SetNuiFocus(true, true)
    Nui.send('activity', {
        open = true,
        activity = {
            id = id,
            label = activity.label,
            tagline = activity.tagline,
            description = activity.description,
            icon = activity.icon,
            enabled = activity.enabled == true,
        },
    })
end

---@param keepFocus? boolean une autre fenêtre (vote de la course) a besoin du curseur
function Activities.close(keepFocus)
    if not Activities.isOpen then return end
    Activities.isOpen = false
    if not keepFocus then SetNuiFocus(false, false) end
    Nui.send('activity', { open = false })
end
