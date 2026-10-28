import { useEffect, useLayoutEffect, useRef, useState, type MouseEvent } from 'react';
import { interactionApi } from '../../api/interactionApi';
import { useGame } from '../../store/GameContext';
import type { InteractionItem } from '../../types/game';
import { Icon } from '../icons/Icon';
import './interaction.css';

/** Hauteurs en rem (servent à aligner le sous-menu sur la ligne survolée) */
const ROW_HEIGHT = 2.75;
const SEPARATOR_HEIGHT = 0.5625;
const HEADER_HEIGHT = 4;

/** Nature de la cible, d'après le préfixe de la ligne d'en-tête (`player:name`...) */
const TARGET_TAGS: Record<string, string> = {
  self: 'Toi',
  player: 'Joueur',
  loot: 'Butin',
  npc: 'PNJ',
  vehicle: 'Véhicule',
};

interface OpenSubmenu {
  id: string;
  /** décalage vertical du sous-menu, en rem */
  top: number;
}

/**
 * Menu d'interaction (Alt maintenu), inspiré de ContextMenu (Kiminaze) :
 * un clic dans le monde vise une cible, son menu s'ouvre à l'endroit du clic.
 */
export function InteractionMenu() {
  const { state, actions } = useGame();
  const items = state.interaction.items;
  const [position, setPosition] = useState({ x: 0, y: 0 });

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') actions.closeInteraction();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [actions]);

  /** Clic dans le monde : le jeu cherche la cible sous le curseur et renvoie son menu */
  const handlePick = (event: MouseEvent) => {
    if (items) return actions.closeInteraction();
    setPosition({ x: event.clientX, y: event.clientY });
    interactionApi.pick(event.clientX / window.innerWidth, event.clientY / window.innerHeight);
  };

  return (
    <div className="interaction" onMouseDown={handlePick}>
      {items ? (
        <ContextPanels items={items} x={position.x} y={position.y} onSelect={actions.interactionAction} />
      ) : (
        <span className="interaction__hint">
          <span className="mono keycap--solid">ALT</span>
          Clique sur toi, un joueur, un butin, un PNJ ou un véhicule
        </span>
      )}
    </div>
  );
}

interface ContextPanelsProps {
  items: InteractionItem[];
  x: number;
  y: number;
  onSelect: (id: string) => void;
}

/** Panneau principal à l'endroit du clic (gardé dans l'écran) et sous-menu à sa droite. */
function ContextPanels({ items, x, y, onSelect }: ContextPanelsProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [submenu, setSubmenu] = useState<OpenSubmenu | null>(null);
  const [place, setPlace] = useState({ left: x, top: y });

  // Un nouveau menu (autre cible) referme le sous-menu
  useEffect(() => setSubmenu(null), [items.length, items[0]?.id]);

  useLayoutEffect(() => {
    const box = ref.current?.getBoundingClientRect();
    if (!box) return;
    const margin = 16;
    setPlace({
      left: Math.max(margin, Math.min(x, window.innerWidth - box.width - margin)),
      top: Math.max(margin, Math.min(y, window.innerHeight - box.height - margin)),
    });
  }, [x, y, items, submenu]);

  // La première ligne « :name » (nom de la cible) devient l'en-tête du menu
  const first = items[0];
  const header = first?.kind === 'info' && first.id.endsWith(':name') ? first : null;
  const rows = header ? items.slice(1) : items;

  let offset = header ? HEADER_HEIGHT : 0;
  const tops = rows.map((item) => {
    const top = offset;
    offset += item.kind === 'separator' ? SEPARATOR_HEIGHT : ROW_HEIGHT;
    return top;
  });
  const openItem = rows.find((item) => item.id === submenu?.id);

  return (
    <div
      ref={ref}
      className="interaction__menu"
      style={{ left: place.left, top: place.top }}
      onMouseDown={(event) => event.stopPropagation()}
    >
      <div className="interaction__panel">
        {header && <Header item={header} />}
        <div className="interaction__rows">
          {rows.map((item, index) => (
            <Row
              key={item.id}
              item={item}
              active={item.id === submenu?.id}
              onHover={() => setSubmenu(item.kind === 'submenu' ? { id: item.id, top: tops[index] } : null)}
              onSelect={() => {
                if (item.kind === 'submenu') setSubmenu({ id: item.id, top: tops[index] });
                else onSelect(item.id);
              }}
            />
          ))}
        </div>
      </div>

      {openItem?.children && submenu && (
        <div className="interaction__panel interaction__panel--sub" style={{ marginTop: `${submenu.top}rem` }}>
          <div className="interaction__rows">
            {openItem.children.map((child) => (
              <Row key={child.id} item={child} onSelect={() => onSelect(child.id)} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function Header({ item }: { item: InteractionItem }) {
  const tag = TARGET_TAGS[item.id.split(':')[0]] ?? 'Cible';
  return (
    <header className="interaction__header">
      {item.icon && <Icon name={item.icon} size={22} strokeWidth={1.8} className="interaction__header-icon" />}
      <div className="interaction__heading">
        <span className="mono interaction__tag">{tag}</span>
        <span className="disp interaction__title">{item.label}</span>
      </div>
      {item.value !== undefined && <span className="mono interaction__header-value">{item.value}</span>}
    </header>
  );
}

interface RowProps {
  item: InteractionItem;
  active?: boolean;
  onHover?: () => void;
  onSelect: () => void;
}

function Row({ item, active, onHover, onSelect }: RowProps) {
  if (item.kind === 'separator') return <div className="interaction__separator" />;

  const clickable = item.kind !== 'info' && !item.disabled;
  const classes = [
    'interaction__row',
    item.kind === 'info' && 'interaction__row--info',
    clickable && 'interaction__row--clickable',
    active && 'interaction__row--active',
    item.disabled && 'interaction__row--disabled',
  ].filter(Boolean).join(' ');

  return (
    <div className={classes} onMouseEnter={onHover} onClick={clickable ? onSelect : undefined}>
      {item.icon && <Icon name={item.icon} size={16} strokeWidth={2} className="interaction__icon" />}
      <span className="interaction__label">{item.label}</span>
      {item.value !== undefined && <span className="mono interaction__value">{item.value}</span>}
      {item.kind === 'submenu' && <span className="interaction__arrow">›</span>}
      {item.kind === 'toggle' && (
        <span className={item.checked ? 'interaction__check interaction__check--on' : 'interaction__check'}>
          {item.checked && <Icon name="check" size={12} strokeWidth={3} />}
        </span>
      )}
    </div>
  );
}
