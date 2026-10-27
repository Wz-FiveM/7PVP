import { useGame } from '../../store/GameContext';
import { isShortcutItem } from '../../utils/inventory';
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
    <section className="shortcuts">
      <div className="shortcuts__slots">
        <span className="label">Raccourcis</span>
        <div className="shortcuts__row">
          {Array.from({ length: config.shortcutSlots }, (_, i) => {
            const slot = i + 1;
            const name = shortcuts[i] || null;
            const item = name ? config.items[name] : undefined;

            return (
              <DropZone key={slot} className="shortcuts__slot" accepts={accepts} onDrop={() => onDrop(slot)}>
                {name && item ? (
                  <ItemTile
                    compact
                    name={name}
                    item={item}
                    keyLabel={`[${slot}]`}
                    onDragStart={() => onDragStart({ kind: 'shortcut', slot, item: name })}
                    onDragEnd={onDragEnd}
                    onContextMenu={() => actions.setShortcut(slot, null)}
                  />
                ) : (
                  <EmptyTile compact keyLabel={`[${slot}]`} />
                )}
              </DropZone>
            );
          })}
        </div>
      </div>
      <p className="muted shortcuts__help">
        Glisse une arme ou un soin sur un emplacement · clic droit pour le vider. En jeu, les touches 1 à{' '}
        {config.shortcutSlots} sortent l'arme ou utilisent l'objet.
      </p>
    </section>
  );
}
