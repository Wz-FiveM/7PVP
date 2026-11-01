import type { ClassDefinition, GameConfig, PlayerState } from '../types/game';

/** Classe choisie par le joueur, si elle existe dans la config. */
export function classOf(config: GameConfig, player: PlayerState | null): ClassDefinition | undefined {
  const id = player?.playerClass?.id;
  return id ? config.classes?.list.find((entry) => entry.id === id) : undefined;
}

/** Quantité d'un ingrédient pour ce joueur, arrondie comme côté serveur (ClassService.ingredientCost). */
export function ingredientCost(config: GameConfig, player: PlayerState | null, count: number): number {
  const factor = classOf(config, player)?.craftCost;
  return factor ? Math.ceil(count * factor - 1e-6) : count;
}
