import { useGame } from '../../store/GameContext';
import { isShortcutItem } from '../../utils/inventory';
import { SectionTitle } from '../menu/SectionTitle';
import type { DragSource } from './drag';
import { DropZone } from './DropZone';
import { EmptyTile } from './EmptyTile';
import { ItemTile } from './ItemTile';

interface ShortcutBarProps {
  drag: DragSource | null;
  onDragStart: (source: DragSource) => void;
  onDragEnd: () => void;
  onDrop: (slot: number) => void;
}

export function ShortcutBar({ drag, onDragStart, onDragEnd, onDrop }: ShortcutBarProps) {
  const { state, actions } = useGame();
  const { config, player } = state;
  const shortcuts = player?.inventory.shortcuts ?? [];
  const accepts = drag !== null && isShortcutItem(config.items[drag.item]?.type);

  return (
    <section className="container">
      <SectionTitle title="Raccourcis" aside="TOUCHES 1 – 7" />
      <div className="tile-grid">
        {Array.from({ length: config.shortcutSlots }, (_, i) => {
          const slot = i + 1;
          const name = shortcuts[i] || null;
          const item = name ? config.items[name] : undefined;

          return (
            <DropZone key={slot} className="shortcut-slot" accepts={accepts} onDrop={() => onDrop(slot)}>
              {name && item ? (
                <ItemTile
                  name={name}
                  item={item}
                  corner={String(slot)}
                  onDragStart={() => onDragStart({ kind: 'shortcut', slot, item: name })}
                  onDragEnd={onDragEnd}
                  onContextMenu={() => actions.setShortcut(slot, null)}
                />
              ) : (
                <EmptyTile corner={String(slot)} />
              )}
            </DropZone>
          );
        })}
      </div>
    </section>
  );
}
