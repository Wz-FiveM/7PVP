import {
  createContext, useCallback, useContext, useEffect, useMemo, useRef, useState,
  type MouseEvent as ReactMouseEvent, type ReactNode,
} from 'react';
import { currentUiScale } from '../../utils/scale';
import { parseTargetKey, targetKey, type DragSource, type DropTarget } from './drag';
import { DragGhost } from './DragGhost';

/**
 * Glisser-déposer à la souris.
 *
 * Le glisser-déposer HTML5 (draggable / dragstart / drop) ne fonctionne pas dans le NUI
 * de FiveM : le navigateur intégré tourne hors écran. On suit donc la souris nous-mêmes :
 * appui sur une tuile, puis au-delà de quelques pixels l'objet suit le curseur, et au
 * relâchement on cherche la zone sous le curseur grâce à l'attribut data-drop.
 */

/** Distance (px à 1080p) avant qu'un clic devienne un glisser */
const DRAG_THRESHOLD = 5;

interface DragState {
  source: DragSource;
  x: number;
  y: number;
}

interface DragContextValue {
  drag: DragState | null;
  /** Cible survolée (clé data-drop), seulement si elle accepte l'objet */
  hover: string | null;
  begin: (source: DragSource, event: ReactMouseEvent) => void;
  canDrop: (target: DropTarget) => boolean;
}

const DragContext = createContext<DragContextValue | null>(null);

export function useDrag(): DragContextValue {
  const context = useContext(DragContext);
  if (!context) throw new Error('useDrag doit être utilisé dans <DragProvider>');
  return context;
}

interface DragProviderProps {
  /** La cible accepte-t-elle cet objet ? */
  accepts: (source: DragSource, target: DropTarget) => boolean;
  /** Dépôt sur une cible valide, ou `null` si l'objet est lâché ailleurs */
  onDrop: (source: DragSource, target: DropTarget | null) => void;
  children: ReactNode;
}

export function DragProvider({ accepts, onDrop, children }: DragProviderProps) {
  const [drag, setDrag] = useState<DragState | null>(null);
  const [hover, setHover] = useState<string | null>(null);
  const pending = useRef<{ source: DragSource; startX: number; startY: number } | null>(null);
  const dragging = useRef<DragSource | null>(null);
  const handlers = useRef({ accepts, onDrop });
  handlers.current = { accepts, onDrop };

  /** Cible sous le curseur, si elle accepte l'objet glissé */
  const targetAt = useCallback((x: number, y: number, source: DragSource): DropTarget | null => {
    const element = document.elementFromPoint(x, y)?.closest<HTMLElement>('[data-drop]');
    const target = parseTargetKey(element?.dataset.drop);
    return target && handlers.current.accepts(source, target) ? target : null;
  }, []);

  useEffect(() => {
    const onMove = (event: MouseEvent) => {
      const start = pending.current;
      if (!start) return;

      if (!dragging.current) {
        const distance = Math.hypot(event.clientX - start.startX, event.clientY - start.startY);
        if (distance < DRAG_THRESHOLD * currentUiScale()) return;
        dragging.current = start.source;
      }

      const target = targetAt(event.clientX, event.clientY, start.source);
      setHover(target ? targetKey(target) : null);
      setDrag({ source: start.source, x: event.clientX, y: event.clientY });
    };

    const onUp = (event: MouseEvent) => {
      const source = dragging.current;
      pending.current = null;
      dragging.current = null;
      if (!source) return;

      // Un glisser ne doit pas déclencher le clic de l'élément sous la souris
      const swallowClick = (e: MouseEvent) => e.stopPropagation();
      window.addEventListener('click', swallowClick, { capture: true, once: true });
      window.setTimeout(() => window.removeEventListener('click', swallowClick, { capture: true }), 0);

      setDrag(null);
      setHover(null);
      handlers.current.onDrop(source, targetAt(event.clientX, event.clientY, source));
    };

    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
    return () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
    };
  }, [targetAt]);

  const value = useMemo<DragContextValue>(
    () => ({
      drag,
      hover,
      begin: (source, event) => {
        if (event.button !== 0) return;
        event.preventDefault();
        pending.current = { source, startX: event.clientX, startY: event.clientY };
      },
      canDrop: (target) => (drag ? handlers.current.accepts(drag.source, target) : false),
    }),
    [drag, hover],
  );

  return (
    <DragContext.Provider value={value}>
      {children}
      {drag && <DragGhost source={drag.source} x={drag.x} y={drag.y} />}
    </DragContext.Provider>
  );
}
