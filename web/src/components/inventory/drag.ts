import type { ContainerId } from '../../types/game';

/** Ce qui est en train d'être glissé dans l'inventaire. */
export type DragSource =
  | { kind: 'container'; container: ContainerId; item: string; count: number }
  | { kind: 'shortcut'; slot: number; item: string };
