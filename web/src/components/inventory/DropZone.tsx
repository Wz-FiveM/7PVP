import { useState, type CSSProperties, type DragEvent, type ReactNode } from 'react';

interface DropZoneProps {
  className?: string;
  style?: CSSProperties;
  /** false : la zone n'accepte pas l'élément glissé actuellement */
  accepts: boolean;
  onDrop: () => void;
  children: ReactNode;
}

/** Zone qui accepte un glisser-déposer et se met en surbrillance au survol. */
export function DropZone({ className = '', style, accepts, onDrop, children }: DropZoneProps) {
  const [over, setOver] = useState(false);

  const handleDragOver = (event: DragEvent) => {
    if (!accepts) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
    setOver(true);
  };

  const handleDrop = (event: DragEvent) => {
    event.preventDefault();
    setOver(false);
    if (accepts) onDrop();
  };

  const classes = [className, accepts && 'drop-zone--ready', over && 'drop-zone--over'].filter(Boolean).join(' ');

  return (
    <div
      className={classes}
      style={style}
      onDragOver={handleDragOver}
      onDragLeave={() => setOver(false)}
      onDrop={handleDrop}
    >
      {children}
    </div>
  );
}
