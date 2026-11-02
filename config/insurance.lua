-- Assurance du sac, chez le banquier : une arme assurée qui reste dans le sac de butin après ta mort,
-- sans que personne ne la prenne, revient dans ton coffre quand le sac disparaît. L'assurance sert une
-- seule fois : elle est consommée à la mort, que l'arme revienne ou non.
Config.Insurance = {
    rate = 0.5, -- part du prix de revente x 2 (le prix boutique, pour une arme vendue)
    minPrice = 500,
    maxPolicies = 3, -- armes assurées en même temps
}
