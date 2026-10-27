import { useEffect } from 'react';

export interface ContextMenuAction {
  label: string;
  onSelect: () => void;
  danger?: boolean;
}

interface ContextMenuProps {
  x: number;
  y: number;
  actions: ContextMenuAction[];
  onClose: () => void;
}

export function ContextMenu({ x, y, actions, onClose }: ContextMenuProps) {
  useEffect(() => {
    window.addEventListener('mousedown', onClose);
    return () => window.removeEventListener('mousedown', onClose);
  }, [onClose]);

  return (
    <ul className="context-menu" style={{ left: x, top: y }} onMouseDown={(event) => event.stopPropagation()}>
      {actions.map((action) => (
        <li key={action.label}>
          <button
            className={action.danger ? 'context-menu__item context-menu__item--danger' : 'context-menu__item'}
            onClick={() => {
              onClose();
              action.onSelect();
            }}
          >
            {action.label}
          </button>
        </li>
      ))}
    </ul>
  );
}
