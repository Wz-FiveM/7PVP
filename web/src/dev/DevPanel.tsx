import { useEffect, useState } from 'react';
import { DEV_ACTIONS, DEV_SCREENS } from './devScenarios';
import './devPanel.css';

const STORAGE_KEY = '7pvp-dev-screen';
const DEFAULT_SCREEN = 'hud';

function readStoredScreen(): string {
  try {
    return window.localStorage.getItem(STORAGE_KEY) ?? DEFAULT_SCREEN;
  } catch {
    return DEFAULT_SCREEN;
  }
}

/**
 * Panneau de dev, affiché seulement avec `npm run dev` (jamais en jeu) :
 * choisit l'écran NUI à afficher et déclenche des événements de test.
 * Le dernier écran choisi est rouvert au rechargement de la page.
 */
export function DevPanel() {
  const [screen, setScreen] = useState(readStoredScreen);
  const [collapsed, setCollapsed] = useState(false);

  const open = (id: string) => {
    const target = DEV_SCREENS.find((s) => s.id === id) ?? DEV_SCREENS[0];
    target.open();
    setScreen(target.id);
    try {
      window.localStorage.setItem(STORAGE_KEY, target.id);
    } catch {
      // stockage indisponible : on garde juste l'écran en mémoire
    }
  };

  // Au chargement : rouvre le dernier écran (après l'initialisation des providers)
  useEffect(() => {
    const timer = window.setTimeout(() => open(readStoredScreen()), 200);
    return () => window.clearTimeout(timer);
  }, []);

  return (
    <aside className={collapsed ? 'dev-panel dev-panel--collapsed' : 'dev-panel'}>
      <button className="dev-panel__toggle mono" onClick={() => setCollapsed(!collapsed)}>
        DEV NUI {collapsed ? '▸' : '▾'}
      </button>
      {!collapsed && (
        <div className="dev-panel__body">
          <span className="dev-panel__title mono">Écran</span>
          <div className="dev-panel__buttons">
            {DEV_SCREENS.map((s) => (
              <button
                key={s.id}
                className={s.id === screen ? 'dev-panel__btn dev-panel__btn--active' : 'dev-panel__btn'}
                onClick={() => open(s.id)}
              >
                {s.label}
              </button>
            ))}
          </div>
          <a className="dev-panel__link" href="./loading.html">
            Écran de chargement (page séparée) ↗
          </a>
          <span className="dev-panel__title mono">Événements</span>
          <div className="dev-panel__buttons">
            {DEV_ACTIONS.map((action) => (
              <button key={action.label} className="dev-panel__btn" onClick={action.run}>
                {action.label}
              </button>
            ))}
          </div>
        </div>
      )}
    </aside>
  );
}
