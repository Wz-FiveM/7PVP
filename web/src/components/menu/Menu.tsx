import { useEffect, useState } from 'react';
import { PAGES, type PageId } from '../../pages';
import { useGame } from '../../store/GameContext';
import { MenuStatus } from './MenuStatus';
import { Sidebar } from './Sidebar';
import './menu.css';

const CLOSE_KEYS = ['Escape', 'F2'];

export function Menu() {
  const { actions } = useGame();
  const [pageId, setPageId] = useState<PageId>('inventory');
  const page = PAGES.find((p) => p.id === pageId)!;
  const Page = page.component;

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (!event.defaultPrevented && CLOSE_KEYS.includes(event.key)) actions.closeMenu();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [actions]);

  return (
    <div className="menu">
      <Sidebar active={pageId} onSelect={setPageId} />
      <main className="menu__main">
        <div className="menu__top">
          <nav className="breadcrumb">
            <span className="muted">Menu</span>
            <span className="breadcrumb__sep">/</span>
            <span className="disp breadcrumb__current">{page.label}</span>
          </nav>
          <MenuStatus />
        </div>
        <header className="page-header cut-s">
          <span className="page-header__mark" />
          <h1 className="disp page-header__title">{page.label}</h1>
        </header>
        <div className="menu__content">
          <Page />
        </div>
      </main>
    </div>
  );
}
