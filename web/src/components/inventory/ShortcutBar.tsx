import { useGame } from '../../store/GameContext';
import { SectionTitle } from '../menu/SectionTitle';
import { useDrag } from './DragProvider';
import { DropZone } from './DropZone';
import { EmptyTile } from './EmptyTile';
import { ItemTile } from './ItemTile';

export function ShortcutBar() {
  const { state, actions } = useGame();
  const { drag, begin } = useDrag();
  const { config, player } = state;
  const shortcuts = player?.inventory.shortcuts ?? [];

  return (
    <section className="container">
      <SectionTitle title="Raccourcis" aside="TOUCHES 1 – 7" />
      <div className="tile-grid">
        {Array.from({ length: config.shortcutSlots }, (_, i) => {
          const slot = i + 1;
          const name = shortcuts[i] || null;
          const item = name ? config.items[name] : undefined;
          const isDragged = drag?.source.kind === 'shortcut' && drag.source.slot === slot;

          return (
            <DropZone key={slot} target={{ kind: 'shortcut', slot }} className="shortcut-slot">
              {name && item ? (
                <ItemTile
                  name={name}
                  item={item}
                  corner={String(slot)}
                  dragging={isDragged}
                  onDragBegin={(event) => begin({ kind: 'shortcut', slot, item: name }, event)}
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
