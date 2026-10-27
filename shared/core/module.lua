---Système de modules de 7PVP.
---
---Chaque fichier déclare son module avec `PVP.define('Nom')` et récupère ses
---dépendances avec `PVP.use('Nom')`. `use` renvoie toujours la même table, même
---si le fichier du module n'est pas encore chargé : l'ordre des fichiers n'a donc
---d'importance que pour l'ordre d'appel des `init`.
---
---Au démarrage, `PVP.boot()` appelle `Module.init()` sur chaque module défini,
---dans l'ordre de déclaration du fxmanifest.
---@class PVP
PVP = {
    modules = {},
    order = {},
}

---@param name string
---@return table
function PVP.use(name)
    local module = PVP.modules[name]
    if not module then
        module = { __name = name }
        PVP.modules[name] = module
    end
    return module
end

---@param name string
---@return table
function PVP.define(name)
    local module = PVP.use(name)
    if module.__defined then
        error(('[7PVP] Le module "%s" est défini deux fois'):format(name))
    end
    module.__defined = true
    PVP.order[#PVP.order + 1] = name
    return module
end

function PVP.boot()
    for name, module in pairs(PVP.modules) do
        if not module.__defined then
            error(('[7PVP] Le module "%s" est utilisé mais jamais défini'):format(name))
        end
    end

    for _, name in ipairs(PVP.order) do
        local module = PVP.modules[name]
        if type(module.init) == 'function' then
            module.init()
        end
    end
end
