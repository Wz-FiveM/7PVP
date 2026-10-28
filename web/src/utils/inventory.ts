import type { ContainerId, GameConfig, ItemStack, ItemStacks, ItemType } from '../types/game';

const TYPE_ORDER: Record<ItemType, number> = { weapon: 0, attachment: 1, ammo: 2, consumable: 3, material: 4, money: 5 };

export const CONTAINERS: ContainerId[] = ['bag', 'protected', 'stash'];

/** Destinations possibles d'un objet (le coffre seulement en zone safe). */
export function moveTargets(from: ContainerId, inSafe: boolean): ContainerId[] {
  return CONTAINERS.filter((id) => id !== from && (inSafe || (id !== 'stash' && from !== 'stash')));
}

/** Libellé de l'action « déplacer vers » dans le menu contextuel. */
export const MOVE_LABELS: Record<ContainerId, string> = {
  bag: 'Vers le sac',
  protected: 'Protéger',
  stash: 'Ranger au coffre',
};

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

/** Accessoires fixés sur une arme. */
export function fittedAttachments(inventory: { attachments?: Record<string, Record<string, boolean>> | [] }, weapon: string): string[] {
  const all = inventory.attachments;
  if (!all || Array.isArray(all)) return [];
  return Object.keys(all[weapon] ?? {});
}

/** Accessoires qui vont sur cette arme. */
export function compatibleAttachments(config: GameConfig, weapon: string): string[] {
  return Object.entries(config.attachments ?? {})
    .filter(([, weapons]) => weapons[weapon])
    .map(([attachment]) => attachment);
}
