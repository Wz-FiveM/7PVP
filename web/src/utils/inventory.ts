import { t } from '../i18n';
import type { ContainerId, GameConfig, Inventory, ItemStack, ItemStacks, ItemType, PlayerState, StashId } from '../types/game';

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

/** Capacité d'un conteneur en kg : celle du sac dépend de la classe du joueur. */
export function capacityOf(config: GameConfig, player: PlayerState | null, id: ContainerId): number {
  if (id === 'bag' && player?.bagCapacity) return player.bagCapacity;
  return config.containers[id]?.capacity ?? 0;
}

/** Lots de `count` objets que le sac peut encore porter, arrondi comme côté serveur (InventoryObject:maxFit). */
export function lotsThatFit(config: GameConfig, player: PlayerState | null, name: string, count: number): number {
  const weight = config.items[name]?.weight ?? 0;
  if (weight <= 0) return Infinity;
  const free = capacityOf(config, player, 'bag') - weightOf(player?.inventory.bag ?? [], config);
  return Math.max(0, Math.floor(Math.floor((free + 1e-6) / weight) / count));
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
  if (to === 'bag') return t('Vers le sac');
  if (to === 'protected') return t('Protéger');
  return t('Ranger : {container}', { container: t(config.containers[to]?.label ?? 'Coffre') });
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

/** Une arme ne sort que du sac. */
export const isWeaponInBag = (inventory: Inventory, name: string): boolean =>
  entriesOf(inventory.bag).some(([item]) => item === name);

/**
 * Objet à afficher sur un raccourci. Une arme au conteneur protégé y reste assignée mais cachée :
 * elle réapparaît dès son retour dans le sac, sauf si un autre objet a pris sa place.
 */
export function shortcutItem(inventory: Inventory, config: GameConfig, index: number): string | null {
  const name = inventory.shortcuts[index] || null;
  if (name && config.items[name]?.type === 'weapon' && !isWeaponInBag(inventory, name)) return null;
  return name;
}

/** Nom de l'objet dans la langue du joueur (l'identifiant si l'objet est inconnu) */
export function itemLabel(config: GameConfig, name: string): string {
  const label = config.items[name]?.label;
  return label ? t(label) : name;
}

