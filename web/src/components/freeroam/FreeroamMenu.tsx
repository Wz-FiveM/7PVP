import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { useGame } from '../../store/GameContext';
import { Icon, type IconName } from '../icons/Icon';
import '../pause/pause.css';
import './freeroam.css';

type FreeroamTab = 'weapons' | 'vehicles' | 'player';

const TABS: { id: FreeroamTab; label: string; icon: IconName }[] = [
  { id: 'weapons', label: 'Armes', icon: 'weapon' },
  { id: 'vehicles', label: 'Véhicules', icon: 'crate' },
  { id: 'player', label: 'Joueur', icon: 'profile' },
];

/** Menu du Freeroam (F2) : armes et véhicules gratuits, outils du joueur, PvP au choix. */
export function FreeroamMenu() {
  const { state, actions } = useGame();
  const { freeroam } = state;
  const [tab, setTab] = useState<FreeroamTab>('weapons');
  const [model, setModel] = useState('');

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' || event.key === 'F2') actions.closeFreeroam();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [actions]);

  const categories = useMemo(() => {
    const map = new Map<string, typeof freeroam.vehicles>();
    for (const vehicle of freeroam.vehicles) {
      map.set(vehicle.category, [...(map.get(vehicle.category) ?? []), vehicle]);
    }
    return [...map.entries()];
  }, [freeroam.vehicles]);

  const spawnTyped = (event: FormEvent) => {
    event.preventDefault();
    if (model.trim()) actions.freeroamAction('vehicle', { model: model.trim() });
  };

  return (
    <div className="pause">
      <aside className="pause__panel freeroam">
        <div className="stripes pause__stripes zone-safe" />
        <header className="pause__header">
          <div className="pause__heading">
            <h1 className="disp pause__title">
              Free<span className="freeroam__accent">roam</span>
            </h1>
            <span className="muted pause__subtitle">Bac à sable : tout est gratuit, rien n'est perdu</span>
          </div>
          <button className="btn btn--small cut-s pause__close" onClick={actions.closeFreeroam} aria-label="Fermer">
            ✕
          </button>
        </header>

        <div className="pause__body">
          <nav className="pause__nav">
            {TABS.map((item) => (
              <button
                key={item.id}
                className={item.id === tab ? 'pause__tab freeroam__tab--active cut-s' : 'pause__tab cut-s'}
                onClick={() => setTab(item.id)}
              >
                <Icon name={item.icon} size={16} strokeWidth={2.2} />
                {item.label}
              </button>
            ))}
            <div className="pause__nav-bottom">
              <button
                className={freeroam.pvp ? 'pause__tab pause__tab--danger cut-s' : 'pause__tab cut-s'}
                onClick={() => actions.freeroamAction('pvp')}
              >
                <Icon name="crosshair" size={16} strokeWidth={2.2} />
                PvP : {freeroam.pvp ? 'activé' : 'désactivé'}
              </button>
            </div>
          </nav>

          <main className="pause__content">
            {tab === 'weapons' && (
              <>
                <div className="freeroam__grid">
                  {freeroam.weapons.map((entry) => (
                    <button
                      key={entry.weapon}
                      className="freeroam__item cut-s"
                      onClick={() => actions.freeroamAction('weapon', { weapon: entry.weapon })}
                    >
                      {entry.label}
                    </button>
                  ))}
                </div>
                <button className="btn btn--danger btn--small cut-s" onClick={() => actions.freeroamAction('clearWeapons')}>
                  Retirer toutes les armes
                </button>
              </>
            )}

            {tab === 'vehicles' && (
              <>
                <form className="freeroam__spawn" onSubmit={spawnTyped}>
                  <input
                    className="field freeroam__input"
                    value={model}
                    onChange={(event) => setModel(event.target.value)}
                    placeholder="Modèle GTA (ex : adder, t20, oppressor)"
                  />
                  <button className="btn btn--primary btn--small cut-s" type="submit">
                    Faire apparaître
                  </button>
                </form>
                {categories.map(([category, list]) => (
                  <section key={category} className="pause__section">
                    <h2 className="disp pause__section-title">
                      <span className="pause__dot freeroam__dot" />
                      {category}
                    </h2>
                    <div className="freeroam__grid">
                      {list.map((vehicle) => (
                        <button
                          key={vehicle.model}
                          className="freeroam__item cut-s"
                          onClick={() => actions.freeroamAction('vehicle', { model: vehicle.model })}
                        >
                          {vehicle.label}
                        </button>
                      ))}
                    </div>
                  </section>
                ))}
                <button className="btn btn--small cut-s" onClick={() => actions.freeroamAction('repair')}>
                  Réparer mon véhicule
                </button>
              </>
            )}

            {tab === 'player' && (
              <div className="freeroam__grid">
                <button className="freeroam__item cut-s" onClick={() => actions.freeroamAction('heal')}>Se soigner</button>
                <button className="freeroam__item cut-s" onClick={() => actions.freeroamAction('armor')}>Armure max</button>
                <button className="freeroam__item cut-s" onClick={() => actions.freeroamAction('waypoint')}>
                  Aller au marqueur
                </button>
              </div>
            )}
          </main>
        </div>
      </aside>
    </div>
  );
}
