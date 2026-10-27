import type { ContainerId, GameConfig, ItemStack, ItemStacks, ItemType } from '../types/game';

const TYPE_ORDER: Record<ItemType, number> = { weapon: 0, ammo: 1, consumable: 2, money: 3 };

export const CONTAINERS: ContainerId[] = ['bag', 'protected'];

export const otherContainer = (id: ContainerId): ContainerId => (id === 'bag' ? 'protected' : 'bag');

/** Lua encode les tables vides en `[]` : on normalise en paires [nom, quantité]. */
export const entriesOf = (stacks: ItemStacks | undefined): [string, number][] =>
  stacks && !Array.isArray(stacks) ? Object.entries(stacks) : [];

/** Piles d'un conteneur, triées par type puis par nom. */
export function stacksOf(stacks: ItemStacks | undefined, config: GameConfig): ItemStack[] {
  return entriesOf(stacks)
    .filter(([name]) => config.items[name])
    .map(([name, count]) => ({ name, count, item: config.items[name] }))
    .sort(
      (a, b) =>
        TYPE_ORDER[a.item.type] - TYPE_ORDER[b.item.type] || a.item.label.localeCompare(b.item.label, 'fr'),
    );
}

export function weightOf(stacks: ItemStacks | undefined, config: GameConfig): number {
  return entriesOf(stacks).reduce((total, [name, count]) => total + (config.items[name]?.weight ?? 0) * count, 0);
}

/** Seules les armes et les consommables peuvent aller dans les raccourcis. */
export const isShortcutItem = (type: ItemType | undefined): boolean => type === 'weapon' || type === 'consumable';

export const itemLabel =(config: GameConfig, name: string): string => config.items[name]?.label ?? name;
