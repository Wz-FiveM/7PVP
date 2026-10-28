---Contrats quotidiens (Config.Contracts) : les mêmes pour tout le monde chaque jour UTC,
---progression sauvegardée par joueur (colonne `contracts`), récompense versée à l'objectif.
---@class ContractServiceModule
local ContractService = PVP.define('ContractService')
local Logger = PVP.use('Logger')

ContractService.DAY = 86400

---@return integer numéro du jour UTC
function ContractService.today()
    return math.floor(os.time() / ContractService.DAY)
end

---@return integer secondes avant les prochains contrats
function ContractService.secondsLeft()
    return ContractService.DAY - os.time() % ContractService.DAY
end

---Contrats du jour : tirage déterministe à partir du numéro du jour (sans toucher à math.random).
---@param day integer
---@return table[]
function ContractService.forDay(day)
    local pool = {}
    for index, contract in ipairs(Config.Contracts.pool) do pool[index] = contract end

    local seed = (day * 2654435761) % 4294967296
    local picked = {}
    for _ = 1, math.min(Config.Contracts.perDay, #pool) do
        seed = (seed * 1103515245 + 12345) % 2147483648
        local index = seed % #pool + 1
        picked[#picked + 1] = table.remove(pool, index)
    end
    return picked
end

---Progression enregistrée, remise à zéro si elle date d'un autre jour.
---@param raw any JSON de la colonne `contracts`, ou table déjà décodée
---@return { day: integer, progress: table<string, integer>, done: table<string, boolean> }
function ContractService.decode(raw)
    local data = raw
    if type(raw) == 'string' then
        local ok, decoded = pcall(json.decode, raw)
        data = ok and decoded or nil
    end
    local today = ContractService.today()
    if type(data) ~= 'table' or data.day ~= today then
        return { day = today, progress = {}, done = {} }
    end
    data.progress = type(data.progress) == 'table' and data.progress or {}
    data.done = type(data.done) == 'table' and data.done or {}
    return data
end

---@param player PvpPlayer
---@return table état du jour du joueur
function ContractService.state(player)
    if player.contracts.day ~= ContractService.today() then
        player.contracts = ContractService.decode(nil)
    end
    return player.contracts
end

---Avance les contrats du jour qui correspondent à l'action du joueur.
---@param player PvpPlayer
---@param contractType string
---@param amount integer
---@param zoneId? string zone de l'action (contrats limités à une zone)
function ContractService.track(player, contractType, amount, zoneId)
    local state = ContractService.state(player)
    for _, contract in ipairs(ContractService.forDay(state.day)) do
        if contract.type == contractType and not state.done[contract.id] and (not contract.zone or contract.zone == zoneId) then
            local progress = math.min(contract.goal, (state.progress[contract.id] or 0) + amount)
            state.progress[contract.id] = progress
            if progress >= contract.goal then
                ContractService.complete(player, contract)
            end
        end
    end
end

---@param player PvpPlayer
---@param contract table
function ContractService.complete(player, contract)
    player.contracts.done[contract.id] = true
    player:addMoney(contract.reward.money)
    player:addXp(contract.reward.xp)
    player:notify(('Contrat terminé : %s (+$%d, +%d XP)'):format(contract.label, contract.reward.money, contract.reward.xp), 'success')
    Logger.info('[contrat] %s : %s', player.name, contract.label)
end

---Contrats du jour avec la progression du joueur (envoyé au client avec la synchro).
---@param player PvpPlayer
---@return table
function ContractService.serialize(player)
    local state = ContractService.state(player)
    local list = {}
    for _, contract in ipairs(ContractService.forDay(state.day)) do
        list[#list + 1] = {
            id = contract.id,
            label = contract.label,
            goal = contract.goal,
            progress = state.progress[contract.id] or 0,
            done = state.done[contract.id] == true,
            reward = contract.reward,
        }
    end
    return { list = list, resetIn = ContractService.secondsLeft() }
end
