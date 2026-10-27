import { useGame } from '../../store/GameContext';
import type { DragSource } from './drag';
import { ItemIcon } from './ItemIcon';

interface DragGhostProps {
  source: DragSource;
  x: number;
  y: number;
}

/** Copie de la tuile qui suit le curseur pendant un glisser. */
export function DragGhost({ source, x, y }: DragGhostProps) {
  const { state } = useGame();
  const item = state.config.items[source.item];
  if (!item) return null;

  return (
    <div className="drag-ghost tile cut" style={{ left: x, top: y }}>
      <ItemIcon name={source.item} type={item.type} />
      <span className="tile__label">{item.label}</span>
      {source.kind === 'container' && <span className="tile__corner mono">x{source.count}</span>}
    </div>
  );
}
