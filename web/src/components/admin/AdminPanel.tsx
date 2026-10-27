import { useEffect, useState, type ComponentType } from 'react';
import { useGame } from '../../store/GameContext';
import { PlayersTab } from './PlayersTab';
import { SelfTab } from './SelfTab';
import { ServerTab } from './ServerTab';
import './admin.css';

const TABS: { id: string; label: string; component: ComponentType }[] = [
  { id: 'players', label: 'Joueurs', component: PlayersTab },
  { id: 'self', label: 'Moi', component: SelfTab },
  { id: 'server', label: 'Serveur', component: ServerTab },
];

/** Panneau admin (F10), à droite pour garder le jeu visible. */
export function AdminPanel() {
  const { actions } = useGame();
  const [tabId, setTabId] = useState(TABS[0].id);
  const Tab = TABS.find((t) => t.id === tabId)!.component;

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.defaultPrevented) return;
      if (event.key === 'Escape' || event.key === 'F10') actions.closeAdmin();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [actions]);

  return (
    <aside className="admin cut">
      <header className="admin__header">
        <span className="admin__badge mono">ADMIN</span>
        <h1 className="disp admin__title">Administration</h1>
        <button className="btn btn--small cut-s admin__close" onClick={actions.closeAdmin} aria-label="Fermer">
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
            {tab.label}
          </button>
        ))}
      </nav>
      <div className="admin__body">
        <Tab />
      </div>
    </aside>
  );
}
