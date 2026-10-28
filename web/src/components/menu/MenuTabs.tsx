import { PAGES, type PageId } from '../../pages';
import { Icon } from '../icons/Icon';

interface MenuTabsProps {
  active: PageId;
  onSelect: (page: PageId) => void;
}

/** Onglets du menu (en haut) : l'onglet actif est rempli. Les pages des PNJ n'apparaissent qu'ouvertes. */
export function MenuTabs({ active, onSelect }: MenuTabsProps) {
  return (
    <nav className="menu-tabs">
      {PAGES.filter((page) => !page.npcOnly || page.id === active).map((page) => (
        <button
          key={page.id}
          className={page.id === active ? 'menu-tabs__tab menu-tabs__tab--active disp' : 'menu-tabs__tab disp'}
          onClick={() => onSelect(page.id)}
        >
          <Icon name={page.icon} size={15} strokeWidth={2} />
          {page.label}
        </button>
      ))}
    </nav>
  );
}
