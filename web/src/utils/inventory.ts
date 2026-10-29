import type { ContainerId, GameConfig, Inventory, ItemStack, ItemStacks, ItemType, StashId } from '../types/game';

const TYPE_ORDER: Record<ItemType, number> = { weapon: 0, attachment: 1, ammo: 2, consumable: 3, vehicle: 4, case: 5, material: 6, money: 7 };

/** Conteneurs portés (les coffres restent chez le banquier) */
export const CARRIED: ContainerId[] = ['bag', 'protected'];

export const isStash = (id: string): id is StashId => id.startsWith('stash');

/** Coffres dans l'ordre de leurs onglets. */
export function stashIds(config: GameConfig): StashId[] {
  return Object.keys(config.containers)
    .filter(isStash)
    .sort((a, b) => (config.containers[a]?.order ?? 0) - (config.containers[b]?.order ?? 0));
}

/** Coffre ouvert d'office ou déjà acheté. */
export function isUnlocked(inventory: Inventory, config: GameConfig, id: StashId): boolean {
  const unlocked = inventory.unlocked;
  return !config.containers[id]?.price || (!!unlocked && !Array.isArray(unlocked) && unlocked[id] === true);
}

/** Destinations possibles d'un objet (`stash` : le coffre ouvert chez le banquier, sinon null). */
export function moveTargets(from: ContainerId, stash: StashId | null): ContainerId[] {
  if (isStash(from)) return stash ? CARRIED : [];
  return [...CARRIED.filter((id) => id !== from), ...(stash ? [stash] : [])];
}

/** Libellé de l'action « déplacer vers » dans le menu contextuel. */
export function moveLabel(to: ContainerId, config: GameConfig): string {
  if (to === 'bag') return 'Vers le sac';
  if (to === 'protected') return 'Protéger';
  return `Ranger : ${config.containers[to]?.label ?? 'Coffre'}`;
}

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
export const isShortcutItem = (type: ItemType | undefined): boolean =>
  type === 'weapon' || type === 'consumable' || type === 'vehicle';

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
