import { PAGES, type PageId } from '../../pages';
import { useGame } from '../../store/GameContext';
import { Icon } from '../icons/Icon';
import { Logo } from '../ui/Logo';

interface SidebarProps {
  active: PageId;
  onSelect: (page: PageId) => void;
}

export function Sidebar({ active, onSelect }: SidebarProps) {
  const { actions } = useGame();

  return (
    <aside className="sidebar">
      <div className="sidebar__brand">
        <Logo size={92} />
      </div>
      <nav className="sidebar__nav">
        {PAGES.map((page) => (
          <button
            key={page.id}
            className={page.id === active ? 'sidebar__item sidebar__item--active disp' : 'sidebar__item disp'}
            onClick={() => onSelect(page.id)}
          >
            <Icon name={page.icon} size={16} strokeWidth={1.8} />
            {page.label}
          </button>
        ))}
      </nav>
      <button className="sidebar__item sidebar__lobby disp" onClick={actions.leaveToLobby}>
        <Icon name="exit" size={16} strokeWidth={1.8} />
        Retour au lobby
      </button>
      <span className="mono sidebar__hint">[F2] FERMER</span>
    </aside>
  );
}
