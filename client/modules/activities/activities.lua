---Modes de jeu du Freeroam (Config.FreeroamActivities) : fenêtre ouverte en parlant à leur PNJ
---dans la zone safe, lancement vérifié par le serveur (server/modules/activities).
---@class ActivitiesModule
local Activities = PVP.define('Activities')
local State = PVP.use('State')
local Nui = PVP.use('Nui')
local Callback = PVP.use('Callback')
local Events = PVP.use('Events')

Activities.isOpen = false

function Activities.init()
    RegisterNUICallback('activityClose', function(_, cb)
        Activities.close()
        cb({})
    end)
    RegisterNUICallback('activityStart', function(data, cb)
        local result = Callback.await(Events.callbacks.activityStart, type(data) == 'table' and data.id or nil)
            or { ok = false, message = 'Le serveur ne répond pas.' }
        if result.ok then Activities.close() end
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

function Activities.close()
    if not Activities.isOpen then return end
    Activities.isOpen = false
    SetNuiFocus(false, false)
    Nui.send('activity', { open = false })
end
