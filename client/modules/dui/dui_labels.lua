---Étiquettes 3D en DUI : une petite page web dans la D.A (web/build/dui.html) rendue en
---texture et dessinée dans le monde, à la place de DrawText. Chaque étiquette visible a son
---navigateur DUI ; ils sont réutilisés (pool) quand une étiquette n'est plus dessinée.
---    DuiLabels.draw('npc:2', coords, { title = 'Armurier', subtitle = 'Voir la boutique', icon = 'shop' })
---À appeler à chaque image tant que l'étiquette doit rester affichée.
---@class DuiLabelsModule
local DuiLabels = PVP.define('DuiLabels')

DuiLabels.WIDTH = 512 -- taille de la texture (voir web/src/dui/dui.css)
DuiLabels.HEIGHT = 160
DuiLabels.MAX = 8 -- navigateurs DUI au maximum
DuiLabels.TXD = '7pvp_labels'
-- Largeur à l'écran (fraction) à la distance de référence (m) ; plus petit en s'éloignant
DuiLabels.BASE_WIDTH = 0.15
DuiLabels.REFERENCE_DISTANCE = 5.0
DuiLabels.MAX_SCALE = 1.5
-- Le contenu est renvoyé régulièrement : la page peut ne pas être prête au premier envoi
DuiLabels.RESEND_INTERVAL = 1000
-- Étiquette non dessinée depuis ce délai (ms) : son navigateur retourne dans le pool
DuiLabels.RELEASE_DELAY = 1000

---@type { dui: integer, texture: string }[] navigateurs libres
DuiLabels.pool = {}
---@type table<string, { slot: table, sent: string|nil, sentAt: integer, drawnAt: integer }>
DuiLabels.active = {}
DuiLabels.created = 0
DuiLabels.txd = nil

function DuiLabels.init()
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then DuiLabels.destroyAll() end
    end)
    CreateThread(DuiLabels.releaseLoop)
end

---@return string
function DuiLabels.url()
    return ('nui://%s/web/build/dui.html'):format(GetCurrentResourceName())
end

---Navigateur DUI de l'étiquette `id` (pris dans le pool ou créé), nil si le maximum est atteint.
---@param id string
---@return table|nil
function DuiLabels.acquire(id)
    local label = DuiLabels.active[id]
    if label then return label end

    local slot = table.remove(DuiLabels.pool)
    if not slot then
        if DuiLabels.created >= DuiLabels.MAX then return nil end
        DuiLabels.created = DuiLabels.created + 1
        DuiLabels.txd = DuiLabels.txd or CreateRuntimeTxd(DuiLabels.TXD)
        local dui = CreateDui(DuiLabels.url(), DuiLabels.WIDTH, DuiLabels.HEIGHT)
        local texture = 'label' .. DuiLabels.created
        CreateRuntimeTextureFromDuiHandle(DuiLabels.txd, texture, GetDuiHandle(dui))
        slot = { dui = dui, texture = texture }
    end

    label = { slot = slot, sent = nil, sentAt = 0, drawnAt = 0 }
    DuiLabels.active[id] = label
    return label
end

---Dessine l'étiquette au-dessus de `coords` (à chaque image).
---@param id string identifiant stable de l'étiquette (ex : 'airdrop:3')
---@param coords vector3
---@param data { title: string, subtitle?: string, accent?: string, icon?: string, progress?: number }
function DuiLabels.draw(id, coords, data)
    local label = DuiLabels.acquire(id)
    if not label then return end
    local now = GetGameTimer()
    label.drawnAt = now

    local content = json.encode(data)
    if content ~= label.sent or now - label.sentAt > DuiLabels.RESEND_INTERVAL then
        SendDuiMessage(label.slot.dui, content)
        label.sent = content
        label.sentAt = now
    end

    -- Menu, menu pause, panneau admin... : l'étiquette passerait derrière l'interface
    if IsNuiFocused() then return end

    local distance = math.max(#(GetFinalRenderedCamCoord() - coords), 1.0)
    local scale = math.min(DuiLabels.MAX_SCALE, DuiLabels.REFERENCE_DISTANCE / distance)
    local width = DuiLabels.BASE_WIDTH * scale
    local height = width * (DuiLabels.HEIGHT / DuiLabels.WIDTH) * GetAspectRatio(false)

    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    DrawSprite(DuiLabels.TXD, label.slot.texture, 0.0, 0.0, width, height, 0.0, 255, 255, 255, 255)
    ClearDrawOrigin()
end

---Rend au pool les navigateurs des étiquettes qui ne sont plus dessinées.
function DuiLabels.releaseLoop()
    while true do
        Wait(500)
        local now = GetGameTimer()
        for id, label in pairs(DuiLabels.active) do
            if now - label.drawnAt > DuiLabels.RELEASE_DELAY then
                DuiLabels.active[id] = nil
                DuiLabels.pool[#DuiLabels.pool + 1] = label.slot
            end
        end
    end
end

function DuiLabels.destroyAll()
    for _, label in pairs(DuiLabels.active) do DestroyDui(label.slot.dui) end
    for _, slot in ipairs(DuiLabels.pool) do DestroyDui(slot.dui) end
    DuiLabels.active = {}
    DuiLabels.pool = {}
end
