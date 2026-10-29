import type { ContainerId } from '../../types/game';
import { isStash } from '../../utils/inventory';

/** Ce qui est en train d'être glissé dans l'inventaire. */
export type DragSource =
  | { kind: 'container'; container: ContainerId; item: string; count: number }
  | { kind: 'shortcut'; slot: number; item: string }
  /** objet du butin ouvert (largage) */
  | { kind: 'loot'; item: string; count: number }
  /** objet de sa propre offre d'échange (lâché ailleurs : retiré de l'offre) */
  | { kind: 'trade'; item: string; count: number };

/** Zone où l'on peut déposer : un conteneur, un emplacement de raccourci ou son offre d'échange. */
export type DropTarget =
  | { kind: 'container'; container: ContainerId }
  | { kind: 'shortcut'; slot: number }
  | { kind: 'trade' };

/** Identifiant texte d'une cible, posé sur l'élément HTML (attribut data-drop). */
export function targetKey(target: DropTarget): string {
  if (target.kind === 'trade') return 'trade:offer';
  return target.kind === 'container' ? `container:${target.container}` : `shortcut:${target.slot}`;
}

export function parseTargetKey(key: string | undefined | null): DropTarget | null {
  if (!key) return null;
  const [kind, value] = key.split(':');
  if (kind === 'container' && (value === 'bag' || value === 'protected' || isStash(value))) {
    return { kind, container: value };
  }
  if (kind === 'shortcut' && Number(value) > 0) return { kind, slot: Number(value) };
  if (kind === 'trade') return { kind };
  return null;
}
