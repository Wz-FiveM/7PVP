---Langue choisie par chaque joueur (gardée sur son PC, voir client/modules/locale/language) :
---publiée dans son state bag pour que les autres voient son drapeau dans les gamertags.
---@class LanguageServiceModule
local LanguageService = PVP.define('LanguageService')
local Locale = PVP.use('Locale')
local Events = PVP.use('Events')

LanguageService.STATE_KEY = 'lang' -- lu par client/modules/admin/gamertags

function LanguageService.init()
    RegisterNetEvent(Events.server.language, function(lang)
        LanguageService.set(source, lang)
    end)
end

---@param source integer
---@param lang any code envoyé par le client
function LanguageService.set(source, lang)
    if type(lang) ~= 'string' or not Locale.isAvailable(lang) then return end
    local state = Player(source).state
    if state[LanguageService.STATE_KEY] ~= lang then state:set(LanguageService.STATE_KEY, lang, true) end
end
