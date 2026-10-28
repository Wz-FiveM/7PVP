import { useCallback, useState, type MouseEvent } from 'react';
import { ContainerSection, type Selection } from '../components/inventory/ContainerSection';
import { ContextMenu, type ContextMenuAction } from '../components/inventory/ContextMenu';
import type { DragSource, DropTarget } from '../components/inventory/drag';
import { DragProvider } from '../components/inventory/DragProvider';
import { QuantityModal } from '../components/inventory/QuantityModal';
import { ShortcutBar } from '../components/inventory/ShortcutBar';
import { useGame } from '../store/GameContext';
import type { ContainerId, ItemStack } from '../types/game';
import {
  compatibleAttachments, entriesOf, weightOf, fittedAttachments, isShortcutItem, itemLabel, MOVE_LABELS, moveTargets,
} from '../utils/inventory';
import '../components/inventory/inventory.css';

/** Conteneurs portés (le coffre n'apparaît que chez le banquier) */
const CARRIED: ContainerId[] = ['bag', 'protected'];

interface PendingQuantity {
  mode: 'move' | 'drop';
  item: string;
  container: ContainerId;
  /** destination d'un déplacement */
  to?: ContainerId;
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
  const [selection, setSelection] = useState<Selection | null>(null);
  const [quantity, setQuantity] = useState<PendingQuantity | null>(null);
  const [contextMenu, setContextMenu] = useState<OpenContextMenu | null>(null);

  const closeContextMenu = useCallback(() => setContextMenu(null), []);
  const closeQuantity = useCallback(() => setQuantity(null), []);

  if (!player) return null;
  // Le coffre ne s'ouvre (et ne s'affiche) qu'à côté du banquier
  const atBanker = Boolean(state.menu.near.stash);

  /** Déplace directement s'il n'y a qu'un objet, sinon demande la quantité. */
  const requestMove = (item: string, from: ContainerId, to: ContainerId, count: number) => {
    if (count === 1) actions.moveItem(item, from, to, 1);
    else setQuantity({ mode: 'move', item, container: from, to, max: count });
  };

  const requestDrop = (item: string, container: ContainerId, count: number) => {
    if (count === 1) actions.dropItem(item, container, 1);
    else setQuantity({ mode: 'drop', item, container, max: count });
  };

  /** Règles du glisser-déposer : où peut-on lâcher quoi ? */
  const acceptsDrop = (source: DragSource, target: DropTarget): boolean => {
    if (target.kind === 'container') {
      return source.kind === 'container' && moveTargets(source.container, atBanker).includes(target.container);
    }
    if (source.kind === 'shortcut' && source.slot === target.slot) return false;
    if (source.kind === 'container' && source.container === 'stash') return false;
    return isShortcutItem(config.items[source.item]?.type);
  };

  const handleDrop = (source: DragSource, target: DropTarget | null) => {
    // Raccourci lâché en dehors des emplacements : on le retire
    if (!target) {
      if (source.kind === 'shortcut') actions.setShortcut(source.slot, null);
      return;
    }

    if (target.kind === 'container') {
      if (source.kind === 'container') requestMove(source.item, source.container, target.container, source.count);
      return;
    }

    const previous = player.inventory.shortcuts[target.slot - 1] || null;
    actions.setShortcut(target.slot, source.item);
    // Glissé depuis un autre raccourci : on échange les deux emplacements
    if (source.kind === 'shortcut') actions.setShortcut(source.slot, previous);
  };

  const handleQuantityConfirm = (count: number) => {
    if (!quantity) return;
    if (quantity.mode === 'move' && quantity.to) {
      actions.moveItem(quantity.item, quantity.container, quantity.to, count);
    } else {
      actions.dropItem(quantity.item, quantity.container, count);
    }
    setQuantity(null);
  };

  const contextActions = (stack: ItemStack, container: ContainerId): ContextMenuAction[] => {
    const list: ContextMenuAction[] = [];
    // Le contenu du coffre n'est pas porté : on le sort d'abord
    const carried = container !== 'stash';
    if (carried && stack.item.type === 'weapon') {
      list.push({ label: 'Équiper', onSelect: () => actions.equip(stack.name) });
      list.push(...attachmentActions(stack.name));
    }
    if (carried && stack.item.type === 'consumable') {
      list.push({ label: 'Utiliser', onSelect: () => actions.consumeItem(stack.name) });
    }
    if (carried && stack.item.type === 'vehicle') {
      list.push({ label: 'Sortir le véhicule', onSelect: () => actions.consumeItem(stack.name) });
    }
    for (const to of moveTargets(container, atBanker)) {
      list.push({ label: MOVE_LABELS[to], onSelect: () => requestMove(stack.name, container, to, stack.count) });
    }
    list.push({ label: 'Jeter', danger: true, onSelect: () => requestDrop(stack.name, container, stack.count) });
    return list;
  };

  /** Accessoires : retirer ceux qui sont fixés, fixer ceux qu'on porte et qui sont compatibles. */
  const attachmentActions = (weapon: string): ContextMenuAction[] => {
    const fitted = fittedAttachments(player.inventory, weapon);
    const carried = new Set(
      [...entriesOf(player.inventory.bag), ...entriesOf(player.inventory.protected)].map(([name]) => name),
    );
    return compatibleAttachments(config, weapon).flatMap((attachment): ContextMenuAction[] => {
      const label = itemLabel(config, attachment);
      if (fitted.includes(attachment)) {
        return [{ label: `Retirer : ${label}`, onSelect: () => actions.attachment(weapon, attachment, false) }];
      }
      if (carried.has(attachment)) {
        return [{ label: `Fixer : ${label}`, onSelect: () => actions.attachment(weapon, attachment, true) }];
      }
      return [];
    });
  };

  /**
   * Alt + clic : toute la pile (ou ce qui tient) part dans « l'autre » conteneur.
   * Chez le banquier : ce qu'on porte va au coffre et le coffre revient dans le sac ;
   * ailleurs : du sac vers le conteneur protégé, et inversement.
   */
  const quickMove = (stack: ItemStack, from: ContainerId) => {
    const to: ContainerId = atBanker ? (from === 'stash' ? 'bag' : 'stash') : from === 'bag' ? 'protected' : 'bag';
    const target = config.containers[to];
    const free = target.capacity - weightOf(player.inventory[to] ?? [], config);
    const fit = stack.item.weight > 0 ? Math.floor((free + 1e-6) / stack.item.weight) : stack.count;
    const count = Math.min(stack.count, fit);
    if (count <= 0) return actions.notify(`Pas assez de place : ${target.label}`, 'error');
    actions.moveItem(stack.name, from, to, count);
  };

  const renderSection = (id: ContainerId) => (
    <ContainerSection
      key={id}
      id={id}
      stacks={player.inventory[id] ?? []}
      selection={selection}
      onSelect={setSelection}
      onItemContextMenu={handleContextMenu}
      onItemDoubleClick={handleDoubleClick}
      onItemQuickMove={quickMove}
    />
  );

  const handleContextMenu = (event: MouseEvent, stack: ItemStack, container: ContainerId) => {
    setSelection({ name: stack.name, container });
    setContextMenu({ x: event.clientX, y: event.clientY, stack, container });
  };

  const handleDoubleClick = (stack: ItemStack) => {
    if (stack.item.type === 'consumable' || stack.item.type === 'vehicle') actions.consumeItem(stack.name);
    if (stack.item.type === 'weapon') actions.equip(stack.name);
  };

  return (
    <DragProvider accepts={acceptsDrop} onDrop={handleDrop}>
      <div className="inventory">
        {atBanker ? (
          // Chez le banquier : ce qu'on porte à gauche, le coffre à droite
          <div className="inventory__split">
            <div className="inventory__column">{CARRIED.map(renderSection)}</div>
            <div className="inventory__column inventory__column--stash">{renderSection('stash')}</div>
          </div>
        ) : (
          CARRIED.map(renderSection)
        )}

        <ShortcutBar />

        <p className="mono inventory__help">
          [GLISSER] DÉPLACER · [ALT + CLIC] VERS {atBanker ? 'LE COFFRE / LE SAC' : 'L\'AUTRE CONTENEUR'} · [DOUBLE-CLIC]
          UTILISER / ÉQUIPER · [CLIC DROIT] ACTIONS · RACCOURCI LÂCHÉ HORS DE LA BARRE = RETIRÉ
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
    </DragProvider>
  );
}
