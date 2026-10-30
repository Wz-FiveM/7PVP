---Traductions de 7PVP. Le texte français sert de clé : locales/<langue>.json associe chaque
---texte français à sa traduction, et un texte absent du fichier reste en français.
---    Locale.t('Niveau %d atteint !', level)
---Les arguments suivent `string.format` (une traduction garde les mêmes %s / %d, dans le même ordre)
---et peuvent eux-mêmes être des `Locale.t` (ex : le nom d'un objet de la config).
---
---Côté client, `Locale.t` renvoie le texte dans la langue choisie par le joueur.
---Côté serveur, il renvoie un message à traduire (le serveur ne connaît pas la langue de chacun) :
---le client le traduit à la réception (Nui.send, Callback.await). Un message serveur ne se concatène
---donc pas (`..`) : passer par un format, ou `Locale.join` pour une liste.
---@class LocaleModule
local Locale = PVP.define('Locale')

Locale.SOURCE = 'fr'
Locale.IS_SERVER = IsDuplicityVersion()
Locale.MAX_DEPTH = 16
-- Langue d'affichage du client (voir client/modules/locale/language.lua) ; le serveur reste en français
Locale.lang = Locale.SOURCE
---@type table<string, table|false> dictionnaires chargés (false : fichier absent ou illisible)
Locale.dictionaries = {}

---@param lang string
---@return table|nil
function Locale.dictionary(lang)
    if lang == Locale.SOURCE then return nil end
    local dictionary = Locale.dictionaries[lang]
    if dictionary == nil then
        local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
        local ok, decoded = pcall(json.decode, raw or '')
        dictionary = ok and type(decoded) == 'table' and decoded or false
        Locale.dictionaries[lang] = dictionary
    end
    return dictionary or nil
end

---@param lang string
---@return boolean
function Locale.isAvailable(lang)
    for _, language in ipairs(Config.Locale.languages) do
        if language.id == lang then return true end
    end
    return false
end

---Traduit `text` dans `lang`, puis le formate avec ses arguments.
---@param lang string
---@param text string
---@param args table
---@param count integer
---@return string
function Locale.format(lang, text, args, count)
    -- Texte reçu du serveur déjà sous forme de message (Locale.t côté serveur), ou nombre
    if type(text) ~= 'string' then
        text = Locale.isMessage(text) and Locale.resolve(text, lang) or tostring(text)
        if count == 0 then return text end
    end
    local dictionary = Locale.dictionary(lang)
    local translated = dictionary and dictionary[text] or text
    if count == 0 then return translated end

    local values = {}
    for i = 1, count do
        values[i] = Locale.resolve(args[i], lang)
    end
    local ok, result = pcall(string.format, translated, table.unpack(values, 1, count))
    if ok then return result end
    -- Traduction mal formée (%s en trop ou en moins) : le texte français plutôt qu'une erreur
    ok, result = pcall(string.format, text, table.unpack(values, 1, count))
    return ok and result or text
end

---Texte destiné au joueur (voir l'en-tête du fichier).
---@param text string texte français, format de `string.format`
---@return string|table
function Locale.t(text, ...)
    local count = select('#', ...)
    if Locale.IS_SERVER then
        return { __t = text, __a = count > 0 and { ... } or nil, __n = count }
    end
    return Locale.format(Locale.lang, text, { ... }, count)
end

---Liste de textes (traduits ou non) jointe par `separator`, ex : le butin « 2x Bandage, $150 ».
---@param parts (string|table)[]
---@param separator? string
---@return string|table
function Locale.join(parts, separator)
    separator = separator or ', '
    if Locale.IS_SERVER then
        return { __j = parts, __s = separator }
    end
    local values = {}
    for i, part in ipairs(parts) do
        values[i] = Locale.resolve(part)
    end
    return table.concat(values, separator)
end

---@param value any
---@return boolean
function Locale.isMessage(value)
    return type(value) == 'table' and (value.__t ~= nil or value.__j ~= nil)
end

---Remplace les messages à traduire contenus dans `value` (à toute profondeur) par leur texte.
---La table d'origine n'est pas modifiée : seules les branches qui changent sont copiées.
---@param value any
---@param lang? string langue d'affichage (par défaut celle du client ; 'fr' pour un journal serveur)
---@return any
function Locale.resolve(value, lang, depth)
    if type(value) ~= 'table' then return value end
    lang = lang or Locale.lang

    if value.__t ~= nil then
        local args = value.__a or {}
        return Locale.format(lang, value.__t, args, value.__n or #args)
    end
    if value.__j ~= nil then
        local values = {}
        for i, part in ipairs(value.__j) do
            values[i] = Locale.resolve(part, lang)
        end
        return table.concat(values, value.__s or ', ')
    end

    depth = (depth or 0) + 1
    if depth > Locale.MAX_DEPTH then return value end
    local copy
    for key, child in pairs(value) do
        if type(child) == 'table' then
            local resolved = Locale.resolve(child, lang, depth)
            if resolved ~= child then
                copy = copy or Locale.shallowCopy(value)
                copy[key] = resolved
            end
        end
    end
    return copy or value
end

---@param value table
---@return table
function Locale.shallowCopy(value)
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = child
    end
    return copy
end
