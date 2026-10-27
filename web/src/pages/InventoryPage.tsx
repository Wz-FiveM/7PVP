import { useCallback, useState, type MouseEvent } from 'react';
import { ContainerSection, type Selection } from '../components/inventory/ContainerSection';
import { ContextMenu, type ContextMenuAction } from '../components/inventory/ContextMenu';
import type { DragSource } from '../components/inventory/drag';
import { QuantityModal } from '../components/inventory/QuantityModal';
import { ShortcutBar } from '../components/inventory/ShortcutBar';
import { useGame } from '../store/GameContext';
import type { ContainerId, ItemStack } from '../types/game';
import { CONTAINERS, itemLabel, otherContainer } from '../utils/inventory';
import '../components/inventory/inventory.css';

interface PendingQuantity {
  mode: 'move' | 'drop';
  item: string;
  container: ContainerId;
  max: number;
}

interface OpenContextMenu {
  x: number;
  y: number;
  stack: ItemStack;
  container: ContainerId;
}

export function InventoryPage() {
  const { state, actions } = useGame();
  const { player, config } = state;
  const [drag, setDrag] = useState<DragSource | null>(null);
  const [selection, setSelection] = useState<Selection | null>(null);
  const [quantity, setQuantity] = useState<PendingQuantity | null>(null);
  const [contextMenu, setContextMenu] = useState<OpenContextMenu | null>(null);

  const closeContextMenu = useCallback(() => setContextMenu(null), []);
  const closeQuantity = useCallback(() => setQuantity(null), []);
  const endDrag = useCallback(() => setDrag(null), []);

  if (!player) return null;

  /** Déplace directement s'il n'y a qu'un objet, sinon demande la quantité. */
  const requestMove = (item: string, from: ContainerId, count: number) => {
    if (count === 1) actions.moveItem(item, from, otherContainer(from), 1);
    else setQuantity({ mode: 'move', item, container: from, max: count });
  };

  const requestDrop = (item: string, container: ContainerId, count: number) => {
    if (count === 1) actions.dropItem(item, container, 1);
    else setQuantity({ mode: 'drop', item, container, max: count });
  };

  const handleContainerDrop = (target: ContainerId) => {
    if (drag?.kind === 'container' && drag.container !== target) {
      requestMove(drag.item, drag.container, drag.count);
    }
    setDrag(null);
  };

  const handleShortcutDrop = (slot: number) => {
    if (!drag) return;
    const previous = player.inventory.shortcuts[slot - 1] || null;
    actions.setShortcut(slot, drag.item);
    // Glissé depuis un autre raccourci : on échange les deux emplacements
    if (drag.kind === 'shortcut' && drag.slot !== slot) {
      actions.setShortcut(drag.slot, previous);
    }
    setDrag(null);
  };

  const handleQuantityConfirm = (count: number) => {
    if (!quantity) return;
    if (quantity.mode === 'move') {
      actions.moveItem(quantity.item, quantity.container, otherContainer(quantity.container), count);
    } else {
      actions.dropItem(quantity.item, quantity.container, count);
    }
    setQuantity(null);
  };

  const contextActions = (stack: ItemStack, container: ContainerId): ContextMenuAction[] => {
    const list: ContextMenuAction[] = [];
    if (stack.item.type === 'weapon') {
      list.push({ label: 'Équiper', onSelect: () => actions.equip(stack.name) });
    }
    if (stack.item.type === 'consumable') {
      list.push({ label: 'Utiliser', onSelect: () => actions.consumeItem(stack.name) });
    }
    list.push({
      label: otherContainer(container) === 'protected' ? 'Protéger' : 'Vers le sac',
      onSelect: () => requestMove(stack.name, container, stack.count),
    });
    list.push({ label: 'Jeter', danger: true, onSelect: () => requestDrop(stack.name, container, stack.count) });
    return list;
  };

  const handleContextMenu = (event: MouseEvent, stack: ItemStack, container: ContainerId) => {
    setSelection({ name: stack.name, container });
    setContextMenu({ x: event.clientX, y: event.clientY, stack, container });
  };

  const handleDoubleClick = (stack: ItemStack) => {
    if (stack.item.type === 'consumable') actions.consumeItem(stack.name);
    if (stack.item.type === 'weapon') actions.equip(stack.name);
  };

  return (
    <div className="inventory">
      {CONTAINERS.map((id) => (
        <ContainerSection
          key={id}
          id={id}
          stacks={player.inventory[id]}
          drag={drag}
          selection={selection}
          onSelect={setSelection}
          onDragStart={setDrag}
          onDragEnd={endDrag}
          onDrop={handleContainerDrop}
          onItemContextMenu={handleContextMenu}
          onItemDoubleClick={handleDoubleClick}
        />
      ))}

      <ShortcutBar drag={drag} onDragStart={setDrag} onDragEnd={endDrag} onDrop={handleShortcutDrop} />

      <p className="mono inventory__help">
        [GLISSER] DÉPLACER · [DOUBLE-CLIC] UTILISER / ÉQUIPER · [CLIC DROIT] ACTIONS
      </p>

      {contextMenu && (
        <ContextMenu
          x={contextMenu.x}
          y={contextMenu.y}
          actions={contextActions(contextMenu.stack, contextMenu.container)}
          onClose={closeContextMenu}
        />
      )}

      {quantity && (
        <QuantityModal
          title={`${quantity.mode === 'move' ? 'Déplacer' : 'Jeter'} : ${itemLabel(config, quantity.item)}`}
          max={quantity.max}
          confirmLabel={quantity.mode === 'move' ? 'Déplacer' : 'Jeter'}
          onConfirm={handleQuantityConfirm}
          onCancel={closeQuantity}
        />
      )}
    </div>
  );
}
