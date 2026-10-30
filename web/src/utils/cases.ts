import { formatNumber } from '../i18n';
import type { CaseDefinition, CaseRarity, CaseReward, GameConfig } from '../types/game';

const FALLBACK_RARITY: CaseRarity = { label: '?', color: '#a7ada4', order: 0 };

export function rarityOf(config: GameConfig, id: string): CaseRarity {
  return config.caseRarities?.[id] ?? FALLBACK_RARITY;
}

export function totalWeight(definition: CaseDefinition): number {
  return definition.rewards.reduce((total, reward) => total + reward.weight, 0);
}

/** Chance en pourcentage, lisible même pour les gros lots (ex : 0,35 %) */
export function formatChance(chance: number): string {
  const digits = chance >= 10 ? 0 : chance >= 1 ? 1 : 2;
  return `${formatNumber(chance, { minimumFractionDigits: digits, maximumFractionDigits: digits })} %`;
}

/** Quantité d'une récompense : « x48-96 », « x2 », rien pour 1 ; l'argent en dollars */
export function rewardCountLabel(reward: Pick<CaseReward, 'item' | 'count'>): string {
  const money = reward.item === 'money';
  const format = (value: number) => (money ? `$${formatNumber(value)}` : value.toString());
  if (Array.isArray(reward.count)) return `${money ? '' : 'x'}${format(reward.count[0])}-${format(reward.count[1])}`;
  const count = reward.count ?? 1;
  if (money) return format(count);
  return count > 1 ? `x${count}` : '';
}

/** Récompenses de la plus rare à la plus courante */
export function sortedRewards(config: GameConfig, definition: CaseDefinition): CaseReward[] {
  return [...definition.rewards].sort(
    (a, b) => rarityOf(config, b.rarity).order - rarityOf(config, a.rarity).order || a.weight - b.weight,
  );
}
