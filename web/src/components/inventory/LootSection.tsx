import type { MouseEvent } from 'react';
import { useGame } from '../../store/GameContext';
import type { ItemStack, LootContainer } from '../../types/game';
import { stacksOf } from '../../utils/inventory';
import { Icon } from '../icons/Icon';
import { SectionTitle } from '../menu/SectionTitle';
import { useDrag } from './DragProvider';
import { ItemTile } from './ItemTile';

interface LootSectionProps {
  loot: LootContainer;
  selected: string | null;
  onSelect: (name: string) => void;
  /** Alt + clic ou double-clic : prend toute la pile (ce qui tient) dans le sac */
  onQuickTake: (stack: ItemStack) => void;
  onTakeAll: () => void;
  onItemContextMenu: (event: MouseEvent, stack: ItemStack) => void;
}

/** Contenu d'un butin ouvert (largage, butin d'un joueur) : on glisse les objets vers son sac ou son conteneur protégé. */
export function LootSection({ loot, selected, onSelect, onQuickTake, onTakeAll, onItemContextMenu }: LootSectionProps) {
  const { state } = useGame();
  const { drag, begin } = useDrag();
  const stacks = stacksOf(loot.items, state.config);

  return (
    <section className="container container--loot">
      <SectionTitle
        title={loot.label}
        icon={<Icon name="crate" size={15} strokeWidth={2.4} className="loot-icon" />}
        badge={<span className="muted container__note">À fouiller</span>}
        aside={
          <button className="btn btn--small btn--primary" onClick={onTakeAll} disabled={stacks.length === 0}>
            Tout prendre
          </button>
        }
      />
      <div className="tile-grid container__grid">
        {stacks.map((stack) => (
          <ItemTile
            key={stack.name}
            name={stack.name}
            item={stack.item}
            corner={stack.item.type === 'money' ? stack.count.toLocaleString('fr-FR') : `x${stack.count}`}
            selected={selected === stack.name}
            dragging={drag?.source.kind === 'loot' && drag.source.item === stack.name}
            onClick={(event) => (event.altKey ? onQuickTake(stack) : onSelect(stack.name))}
            onDragBegin={(event) => begin({ kind: 'loot', item: stack.name, count: stack.count }, event)}
            onDoubleClick={() => onQuickTake(stack)}
            onContextMenu={(event) => onItemContextMenu(event, stack)}
          />
        ))}
      </div>
    </section>
  );
}
