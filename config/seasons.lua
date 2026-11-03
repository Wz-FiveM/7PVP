-- Récompenses de fin de saison : le classement de la saison passée paie des points boutique et un titre.
-- Rang = classement par kills de la saison (voir PlayerRepository.topSeason).
-- Les titres passent par t(variable) : à ajouter à la main dans locales/.
Config.SeasonRewards = {
    minKills = 10, -- en dessous, pas de récompense, même dans le top
    ranks = {
        { from = 1, to = 1, points = 1000, title = 'Champion de saison', id = 'top1' },
        { from = 2, to = 3, points = 500, title = 'Podium de saison', id = 'top3' },
        { from = 4, to = 10, points = 200, title = 'Top 10 de saison', id = 'top10' },
    },
}

-- Passe de saison : une piste gratuite, une piste premium achetée en points boutique, remises à zéro chaque saison.
-- sources : points de passe par unité de compteur (Config.AchievementStats).
-- reward : { money, xp, items = { objet = quantité }, title = texte d'un titre de saison }
Config.SeasonPass = {
    premiumPrice = 1000, -- points boutique
    pointsPerTier = 200,
    sources = {
        playerKill = 10,
        assists = 5,
        headshots = 3,
        bounties = 25,
        revenges = 5,
        nemeses = 15,
        npcKill = 1,
        lootCorpse = 1,
        lootAirdrop = 25,
        craft = 2,
        hordeSurvive = 40,
        contracts = 50,
        captures = 40,
        conflictWins = 60,
    },
    tiers = {},
}

-- 30 paliers : argent à chaque palier, objets tous les 5 paliers. Le dernier palier premium donne un titre.
do
    local items = {
        { free = { bandage = 5 }, premium = { medkit = 5, armor = 1 } },
        { free = { mag_556 = 4 }, premium = { heavy_kevlar = 1, drug_health = 2 } },
        { free = { firstaid = 3 }, premium = { weapon_carbinerifle = 1, mag_556 = 8 } },
        { free = { armor = 1 }, premium = { antizin = 3, drug_stamina = 2, medkit = 5 } },
        { free = { medkit = 3 }, premium = { weapon_combatmg = 1, mag_mg = 3 } },
        { free = { heavy_kevlar = 1 }, premium = { weapon_heavysniper = 1, mag_762 = 6 } },
    }
    for tier = 1, 30 do
        local entry = {
            free = { money = 200 + tier * 20 },
            premium = { money = 500 + tier * 50, xp = 100 },
        }
        if tier % 5 == 0 then
            local bonus = items[tier / 5]
            entry.free.items = bonus.free
            entry.premium.items = bonus.premium
        end
        Config.SeasonPass.tiers[tier] = entry
    end
    Config.SeasonPass.tiers[30].premium.title = 'Vétéran de saison'
end
