import { PAGES, type PageId } from '../../pages';
import { Icon } from '../icons/Icon';
import { Logo } from '../ui/Logo';

interface SidebarProps {
  active: PageId;
  onSelect: (page: PageId) => void;
}

export function Sidebar({ active, onSelect }: SidebarProps) {
  return (
    <aside className="sidebar">
      <div className="sidebar__brand">
        <Logo size={22} />
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
      <span className="mono sidebar__hint">[F2] FERMER</span>
    </aside>
  );
}
