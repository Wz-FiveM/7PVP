import { useEffect, useState } from 'react';
import { PAGES, type PageId } from '../../pages';
import { useGame } from '../../store/GameContext';
import { TopBar } from './TopBar';
import './menu.css';

const CLOSE_KEYS = ['Escape', 'F2'];

export function Menu() {
  const { actions } = useGame();
  const [pageId, setPageId] = useState<PageId>('inventory');
  const Page = PAGES.find((p) => p.id === pageId)!.component;

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (!event.defaultPrevented && CLOSE_KEYS.includes(event.key)) actions.closeMenu();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [actions]);

  return (
    <div className="menu">
      <TopBar active={pageId} onSelect={setPageId} />
      <main className="menu__content">
        <Page />
      </main>
    </div>
  );
}
