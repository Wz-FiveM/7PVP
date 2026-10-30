import { useEffect, useState } from 'react';
import { PAGES, type PageId } from '../../pages';
import { useTypingFocus } from '../../hooks/useTypingFocus';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { isMenuCloseKey } from '../../utils/keys';
import { CaseOpening } from '../cases/CaseOpening';
import { MenuStatus } from './MenuStatus';
import { MenuTabs } from './MenuTabs';
import './menu.css';

export function Menu() {
  const t = useT();
  const { state, actions } = useGame();
  const [pageId, setPageId] = useState<PageId>('inventory');
  useTypingFocus();

  // Parler à un PNJ ouvre directement sa page (boutique, coffre, fabrication...)
  useEffect(() => {
    const requested = PAGES.find((p) => p.id === state.menu.page);
    if (requested) setPageId(requested.id);
  }, [state.menu.page, state.menu.key]);
  const page = PAGES.find((p) => p.id === pageId)!;
  const Page = page.component;
  const player = state.player;

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (!event.defaultPrevented && isMenuCloseKey(event)) actions.closeMenu();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [actions]);

  return (
    <div className="menu screen-veil">
      <header className="menu__bar">
        <div className="menu__heading">
          <span className="mono menu__eyebrow">
            {t('OPÉRATEUR')}{player ? ` · ${player.name} · ${t('NIV. {level}', { level: player.level })}` : ''}
          </span>
          <h1 className="disp menu__title">{t(page.label)}</h1>
        </div>
        <MenuTabs active={pageId} onSelect={setPageId} />
        <MenuStatus />
      </header>
      <div className="menu__content">
        <Page />
      </div>
      {state.caseSpin && <CaseOpening spin={state.caseSpin} />}
    </div>
  );
}
