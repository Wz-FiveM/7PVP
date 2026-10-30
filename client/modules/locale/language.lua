---Langue choisie par le joueur : gardée sur son PC (KVP), détectée depuis GTA V à la première
---connexion. Le choix se fait dans le menu pause, le lobby ou avec /langue <code>.
---Les textes passent par Locale (shared/core/locale.lua).
---@class LanguageModule
local Language = PVP.define('Language')
local Locale = PVP.use('Locale')
local Nui = PVP.use('Nui')
local Hud = PVP.use('Hud')
local Events = PVP.use('Events')

Language.KVP = '7pvp:language'
-- GetCurrentLanguage() -> code de la langue (0 anglais, 1 français, 2 allemand, 3 italien,
-- 4 espagnol, 5 portugais du Brésil, 11 espagnol du Mexique)
Language.GAME_LANGUAGES = { [0] = 'en', [1] = 'fr', [2] = 'de', [3] = 'it', [4] = 'es', [5] = 'pt', [11] = 'es' }

function Language.init()
    Locale.lang = Language.initial()

    RegisterNUICallback('setLanguage', function(data, cb)
        cb({ ok = Language.set(type(data) == 'table' and data.lang or nil) })
    end)

    -- /langue en, /language en (sans code : liste des langues)
    for _, command in ipairs({ 'langue', 'language' }) do
        RegisterCommand(command, function(_, args)
            Language.command(args[1])
        end, false)
    end
end

---@return string langue enregistrée, sinon celle de GTA V, sinon celle par défaut
function Language.initial()
    local saved = GetResourceKvpString(Language.KVP)
    if saved and Locale.isAvailable(saved) then return saved end

    if Config.Locale.detectGameLanguage then
        local game = Language.GAME_LANGUAGES[GetCurrentLanguage()]
        if game and Locale.isAvailable(game) then return game end
    end
    return Config.Locale.default
end

---@param lang any
---@return boolean
function Language.set(lang)
    if type(lang) ~= 'string' or not Locale.isAvailable(lang) then return false end
    SetResourceKvp(Language.KVP, lang)
    if lang == Locale.lang then return true end

    Locale.lang = lang
    Nui.send('locale', Language.payload())
    -- Le HUD renvoie ses données (textes compris) à la prochaine mise à jour
    Hud.invalidate()
    TriggerEvent(Events.internal.languageChanged, lang)
    return true
end

---@return { lang: string, languages: table[] }
function Language.payload()
    return { lang = Locale.lang, languages = Config.Locale.languages }
end

---@param code? string
function Language.command(code)
    if code then
        code = code:lower()
        if Language.set(code) then
            return Nui.notify(Locale.t('Langue : %s', Language.label(code)), 'success')
        end
    end

    local codes = {}
    for _, language in ipairs(Config.Locale.languages) do
        codes[#codes + 1] = ('%s (%s)'):format(language.id, language.label)
    end
    Nui.notify(Locale.t('Langues : %s. Exemple : /langue en', table.concat(codes, ', ')), code and 'error' or 'info')
end

---@param lang string
---@return string
function Language.label(lang)
    for _, language in ipairs(Config.Locale.languages) do
        if language.id == lang then return language.label end
    end
    return lang
end
