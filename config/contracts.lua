-- Contrats quotidiens : chaque jour (UTC), `perDay` contrats sont tirés au sort dans `pool`,
-- les mêmes pour tous les joueurs. La récompense est versée dès que l'objectif est atteint.
--
-- type : npcKill (zombies tués, `zone` facultative), playerKill, lootCorpse (corps fouillés),
--        lootAirdrop (largages fouillés), craft (objets fabriqués), hordeSurvive (hordes repoussées)
Config.Contracts = {
    perDay = 3,
    pool = {
        { id = 'zombies_20', label = 'Tue 20 zombies', type = 'npcKill', goal = 20, reward = { money = 400, xp = 150 } },
        { id = 'zombies_50', label = 'Tue 50 zombies', type = 'npcKill', goal = 50, reward = { money = 900, xp = 350 } },
        { id = 'zombies_port', label = 'Tue 15 zombies au port', type = 'npcKill', zone = 'port', goal = 15, reward = { money = 600, xp = 250 } },
        { id = 'zombies_sandy', label = 'Tue 15 zombies à l\'aérodrome', type = 'npcKill', zone = 'sandy_airfield', goal = 15, reward = { money = 500, xp = 200 } },
        { id = 'players_3', label = 'Élimine 3 joueurs', type = 'playerKill', goal = 3, reward = { money = 800, xp = 300 } },
        { id = 'corpses_8', label = 'Fouille 8 corps de zombies', type = 'lootCorpse', goal = 8, reward = { money = 350, xp = 120 } },
        { id = 'airdrop_1', label = 'Fouille un largage aérien', type = 'lootAirdrop', goal = 1, reward = { money = 700, xp = 250 } },
        { id = 'craft_5', label = 'Fabrique 5 objets', type = 'craft', goal = 5, reward = { money = 300, xp = 150 } },
        { id = 'horde_1', label = 'Repousse une horde', type = 'hordeSurvive', goal = 1, reward = { money = 800, xp = 300 } },
    },
}
