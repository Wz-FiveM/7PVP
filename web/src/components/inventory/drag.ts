import type { ContainerId } from '../../types/game';

/** Ce qui est en train d'être glissé dans l'inventaire. */
export type DragSource =
  | { kind: 'container'; container: ContainerId; item: string; count: number }
  | { kind: 'shortcut'; slot: number; item: string }
  /** objet du butin ouvert (largage) */
  | { kind: 'loot'; item: string; count: number };

/** Zone où l'on peut déposer : un conteneur ou un emplacement de raccourci. */
export type DropTarget = { kind: 'container'; container: ContainerId } | { kind: 'shortcut'; slot: number };

/** Identifiant texte d'une cible, posé sur l'élément HTML (attribut data-drop). */
export function targetKey(target: DropTarget): string {
  return target.kind === 'container' ? `container:${target.container}` : `shortcut:${target.slot}`;
}

export function parseTargetKey(key: string | undefined | null): DropTarget | null {
  if (!key) return null;
  const [kind, value] = key.split(':');
  if (kind === 'container' && (value === 'bag' || value === 'protected' || value === 'stash')) {
    return { kind, container: value };
  }
  if (kind === 'shortcut' && Number(value) > 0) return { kind, slot: Number(value) };
  return null;
}
