import type { ReactNode } from 'react';
import { targetKey, type DropTarget } from './drag';
import { useDrag } from './DragProvider';

interface DropZoneProps {
  target: DropTarget;
  className?: string;
  children: ReactNode;
}

/**
 * Zone de dépôt : repérée sous le curseur grâce à l'attribut data-drop
 * (voir DragProvider), mise en évidence quand elle peut recevoir l'objet glissé.
 */
export function DropZone({ target, className = '', children }: DropZoneProps) {
  const { drag, hover, canDrop } = useDrag();
  const key = targetKey(target);
  const ready = drag !== null && canDrop(target);

  const classes = [className, ready && 'drop-zone--ready', hover === key && 'drop-zone--over'].filter(Boolean).join(' ');

  return (
    <div className={classes} data-drop={key}>
      {children}
    </div>
  );
}
