import type { DragEvent, MouseEvent } from 'react';
import type { ItemDefinition } from '../../types/game';
import { Brackets } from '../ui/Brackets';
import { ItemIcon } from './ItemIcon';

interface ItemTileProps {
  name: string;
  item: ItemDefinition;
  /** Texte en bas à droite (quantité, prix...) */
  corner?: string;
  /** Texte en bas à gauche, à la place du nom (ex : touche [1]) */
  keyLabel?: string;
  selected?: boolean;
  /** Liseré cyan : objet dans le conteneur protégé */
  protectedItem?: boolean;
  disabled?: boolean;
  compact?: boolean;
  onClick?: () => void;
  onDoubleClick?: () => void;
  onContextMenu?: (event: MouseEvent) => void;
  onDragStart?: () => void;
  onDragEnd?: () => void;
}

export function ItemTile({
  name, item, corner, keyLabel, selected, protectedItem, disabled, compact,
  onClick, onDoubleClick, onContextMenu, onDragStart, onDragEnd,
}: ItemTileProps) {
  const draggable = Boolean(onDragStart) && !disabled;

  const handleDragStart = (event: DragEvent) => {
    // Chromium (CEF) exige des données pour démarrer un glisser-déposer
    event.dataTransfer.setData('text/plain', name);
    event.dataTransfer.effectAllowed = 'move';
    onDragStart?.();
  };

  const handleContextMenu = (event: MouseEvent) => {
    event.preventDefault();
    onContextMenu?.(event);
  };

  const classes = [
    'tile',
    'cut',
    compact && 'tile--compact',
    selected && 'tile--selected',
    protectedItem && 'tile--protected',
    disabled && 'tile--disabled',
  ].filter(Boolean).join(' ');

  return (
    <div
      className="tile-wrap"
      draggable={draggable}
      onDragStart={draggable ? handleDragStart : undefined}
      onDragEnd={onDragEnd}
      onClick={disabled ? undefined : onClick}
      onDoubleClick={disabled ? undefined : onDoubleClick}
      onContextMenu={handleContextMenu}
      title={item.label}
    >
      <div className={classes}>
        <ItemIcon name={name} type={item.type} />
        {keyLabel ? <span className="tile__key">{keyLabel}</span> : <span className="tile__label">{item.label}</span>}
        {corner && <span className="tile__corner mono">{corner}</span>}
      </div>
      {selected && <Brackets />}
    </div>
  );
}
