import type { MouseEvent } from 'react';
import type { ItemDefinition } from '../../types/game';
import { Brackets } from '../ui/Brackets';
import { ItemIcon } from './ItemIcon';

interface ItemTileProps {
  name: string;
  item: ItemDefinition;
  /** Texte en bas à droite (quantité, prix, numéro de touche...) */
  corner?: string;
  selected?: boolean;
  /** Liseré cyan : objet dans le conteneur protégé */
  protectedItem?: boolean;
  /** Tuile en cours de glisser : affichée en retrait */
  dragging?: boolean;
  disabled?: boolean;
  onClick?: () => void;
  onDoubleClick?: () => void;
  onContextMenu?: (event: MouseEvent) => void;
  /** Appui de la souris : point de départ d'un glisser (voir DragProvider) */
  onDragBegin?: (event: MouseEvent) => void;
}

export function ItemTile({
  name, item, corner, selected, protectedItem, dragging, disabled,
  onClick, onDoubleClick, onContextMenu, onDragBegin,
}: ItemTileProps) {
  const handleContextMenu = (event: MouseEvent) => {
    event.preventDefault();
    onContextMenu?.(event);
  };

  const classes = [
    'tile',
    'cut',
    selected && 'tile--selected',
    protectedItem && 'tile--protected',
    dragging && 'tile--dragging',
    disabled && 'tile--disabled',
  ].filter(Boolean).join(' ');

  return (
    <div
      className="tile-wrap"
      onMouseDown={disabled ? undefined : onDragBegin}
      onClick={disabled ? undefined : onClick}
      onDoubleClick={disabled ? undefined : onDoubleClick}
      onContextMenu={handleContextMenu}
      title={item.label}
    >
      <div className={classes}>
        <ItemIcon name={name} type={item.type} />
        <span className="tile__label">{item.label}</span>
        {corner && <span className="tile__corner mono">{corner}</span>}
      </div>
      {selected && !dragging && <Brackets />}
    </div>
  );
}
