import { useEffect, useState, type ComponentType } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { FreeroamTab } from './FreeroamTab';
import { LootTab } from './LootTab';
import { PlayersTab } from './PlayersTab';
import { SelfTab } from './SelfTab';
import { ServerTab } from './ServerTab';
import './admin.css';

/** wide : onglet qui a besoin de place (le panneau s'élargit) */
const TABS: { id: string; label: string; component: ComponentType; wide?: boolean }[] = [
  { id: 'players', label: 'Joueurs', component: PlayersTab },
  { id: 'self', label: 'Moi', component: SelfTab },
  { id: 'server', label: 'Serveur', component: ServerTab },
  { id: 'loot', label: 'Butin', component: LootTab, wide: true },
  { id: 'freeroam', label: 'Freeroam', component: FreeroamTab, wide: true },
];

/** Panneau admin (F10), à droite pour garder le jeu visible. */
export function AdminPanel() {
  const t = useT();
  const { actions } = useGame();
  const [tabId, setTabId] = useState(TABS[0].id);
  const tab = TABS.find((entry) => entry.id === tabId)!;
  const Tab = tab.component;

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.defaultPrevented) return;
      if (event.key === 'Escape' || event.key === 'F10') actions.closeAdmin();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [actions]);

  return (
    <aside className={tab.wide ? 'admin admin--wide cut' : 'admin cut'}>
      <header className="admin__header">
        <span className="admin__badge mono">ADMIN</span>
        <h1 className="disp admin__title">{t('Administration')}</h1>
        <button className="btn btn--small cut-s admin__close" onClick={actions.closeAdmin} aria-label={t('Fermer')}>
          ✕
        </button>
      </header>
      <nav className="admin__tabs">
        {TABS.map((tab) => (
          <button
            key={tab.id}
            className={tab.id === tabId ? 'admin__tab admin__tab--active disp' : 'admin__tab disp'}
            onClick={() => setTabId(tab.id)}
          >
            {t(tab.label)}
          </button>
        ))}
      </nav>
      <div className="admin__body">
        <Tab />
      </div>
    </aside>
  );
}
