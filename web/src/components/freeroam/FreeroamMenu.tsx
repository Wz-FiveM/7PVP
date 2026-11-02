import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { useTypingFocus } from '../../hooks/useTypingFocus';
import { isMenuCloseKey } from '../../utils/keys';
import { Icon, type IconName } from '../icons/Icon';
import './freeroam.css';

type FreeroamTab = 'weapons' | 'vehicles' | 'player' | 'activities';

const TABS: { id: FreeroamTab; label: string; icon: IconName }[] = [
  { id: 'weapons', label: 'Armes', icon: 'weapon' },
  { id: 'vehicles', label: 'Véhicules', icon: 'vehicle' },
  { id: 'player', label: 'Joueur', icon: 'profile' },
  { id: 'activities', label: 'Modes de jeu', icon: 'flag' },
];

const PLAYER_ACTIONS: { action: string; label: string; icon: IconName }[] = [
  { action: 'heal', label: 'Se soigner', icon: 'bandage' },
  { action: 'armor', label: 'Armure max', icon: 'armor' },
  { action: 'waypoint', label: 'Aller au marqueur', icon: 'flag' },
];

/** Images déjà connues comme absentes : évite de les redemander à chaque rendu. */
const missingImages = new Set<string>();

/** Première image `web/public/items/<nom>.png` qui existe, sinon l'icône au trait. */
function Picture({ files, icon, size }: { files: string[]; icon: IconName; size: number }) {
  const [, refresh] = useState(0);
  const file = files.find((name) => !missingImages.has(name));

  if (!file) return <Icon name={icon} size={size} strokeWidth={1.3} className="freeroam__no-image" />;
  return (
    <img
      className="freeroam__image"
      src={`./items/${file}.png`}
      alt=""
      draggable={false}
      onError={() => {
        missingImages.add(file);
        refresh((count) => count + 1);
      }}
    />
  );
}

/** Les images d'armes ne portent pas toutes le préfixe weapon_ (WEAPON_BAT : weapon_bat.png, WEAPON_SMG : smg.png). */
function weaponFiles(weapon: string) {
  const name = weapon.toLowerCase().replace(/^weapon_/, '');
  return [name, `weapon_${name}`];
}

function weaponIcon(weapon: string): IconName {
  return weapon === 'WEAPON_PARACHUTE' ? 'parachute' : 'weapon';
}

/** Menu du Freeroam (touche du menu) : armes et véhicules gratuits, outils du joueur, modes de jeu, PvP au choix. */
export function FreeroamMenu() {
  const t = useT();
  const { state, actions } = useGame();
  const { freeroam } = state;
  const [tab, setTab] = useState<FreeroamTab>('weapons');
  const [model, setModel] = useState('');
  const [selected, setSelected] = useState<{ weapon?: string; vehicle?: string; activity?: string }>({});
  useTypingFocus();

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (isMenuCloseKey(event)) actions.closeFreeroam();
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

  const weapon = freeroam.weapons.find((entry) => entry.weapon === selected.weapon) ?? freeroam.weapons[0];
  const vehicle = freeroam.vehicles.find((entry) => entry.model === selected.vehicle) ?? freeroam.vehicles[0];
  const activity = freeroam.activities.find((entry) => entry.id === selected.activity) ?? freeroam.activities[0];
  const owned = freeroam.weapons.filter((entry) => freeroam.owned.includes(entry.weapon));

  const takeWeapon = (id: string) => actions.freeroamAction('weapon', { weapon: id });
  const spawnVehicle = (name: string) => actions.freeroamAction('vehicle', { model: name });
  const gotoActivity = (id: string) => actions.freeroamAction('activity', { id });

  const spawnTyped = (event: FormEvent) => {
    event.preventDefault();
    if (model.trim()) spawnVehicle(model.trim());
  };

  return (
    <div className="freeroam-menu">
      <section className="freeroam__panel">
        <div className="stripes freeroam__stripes zone-safe" />
        <header className="freeroam__header">
          <h1 className="disp freeroam__title">
            Free<span className="freeroam__accent">roam</span>
          </h1>
          <span className="muted freeroam__subtitle">{t("Bac à sable : tout est gratuit, rien n'est perdu")}</span>
          <button
            className={freeroam.pvp ? 'freeroam__pvp freeroam__pvp--on' : 'freeroam__pvp'}
            aria-pressed={freeroam.pvp}
            onClick={() => actions.freeroamAction('pvp')}
          >
            <span className="freeroam__switch" />
            {freeroam.pvp ? t('PvP : activé') : t('PvP : désactivé')}
          </button>
          <button className="freeroam__close" onClick={actions.closeFreeroam} aria-label={t('Fermer')}>
            ✕
          </button>
        </header>

        <div className="freeroam__body">
          <nav className="freeroam__nav">
            {TABS.map((item) => (
              <button
                key={item.id}
                className={item.id === tab ? 'freeroam__tab freeroam__tab--active' : 'freeroam__tab'}
                onClick={() => setTab(item.id)}
              >
                <Icon name={item.icon} size={20} strokeWidth={2.2} />
                {t(item.label)}
              </button>
            ))}
          </nav>

          <main className="freeroam__content">
            {tab === 'weapons' && (
              <div className="freeroam__grid">
                {freeroam.weapons.map((entry) => (
                  <button
                    key={entry.weapon}
                    className={entry.weapon === weapon?.weapon ? 'freeroam__tile freeroam__tile--selected' : 'freeroam__tile'}
                    aria-pressed={entry.weapon === weapon?.weapon}
                    onClick={() => setSelected({ ...selected, weapon: entry.weapon })}
                    onDoubleClick={() => takeWeapon(entry.weapon)}
                  >
                    <span className="freeroam__plate freeroam__plate--weapon">
                      <Picture files={weaponFiles(entry.weapon)} icon={weaponIcon(entry.weapon)} size={36} />
                    </span>
                    <span className="freeroam__label">{t(entry.label)}</span>
                  </button>
                ))}
              </div>
            )}

            {tab === 'vehicles' && (
              <>
                <form className="freeroam__spawn" onSubmit={spawnTyped}>
                  <input
                    className="field mono freeroam__input"
                    value={model}
                    onChange={(event) => setModel(event.target.value)}
                    placeholder={t('Modèle GTA (ex : adder, t20, oppressor)')}
                  />
                  <button className="freeroam__action freeroam__action--small" type="submit">
                    {t('Faire apparaître')}
                  </button>
                </form>
                {categories.map(([category, list]) => (
                  <section key={category} className="freeroam__section">
                    <h2 className="disp freeroam__section-title">
                      <span className="freeroam__dot" />
                      {t(category)}
                    </h2>
                    <div className="freeroam__grid">
                      {list.map((entry) => (
                        <button
                          key={entry.model}
                          className={entry.model === vehicle?.model ? 'freeroam__tile freeroam__tile--selected' : 'freeroam__tile'}
                          aria-pressed={entry.model === vehicle?.model}
                          onClick={() => setSelected({ ...selected, vehicle: entry.model })}
                          onDoubleClick={() => spawnVehicle(entry.model)}
                        >
                          <span className="freeroam__plate freeroam__plate--vehicle">
                            <Picture files={[entry.model]} icon="vehicle" size={36} />
                          </span>
                          <span className="freeroam__label">{t(entry.label)}</span>
                        </button>
                      ))}
                    </div>
                  </section>
                ))}
              </>
            )}

            {tab === 'player' && (
              <div className="freeroam__player">
                {PLAYER_ACTIONS.map((entry) => (
                  <button key={entry.action} className="freeroam__player-action" onClick={() => actions.freeroamAction(entry.action)}>
                    <Icon name={entry.icon} size={60} strokeWidth={1.5} />
                    <span className="disp freeroam__player-label">{t(entry.label)}</span>
                  </button>
                ))}
              </div>
            )}

            {tab === 'activities' &&
              freeroam.activities.map((entry) => (
                <button
                  key={entry.id}
                  className={entry.id === activity?.id ? 'freeroam__mode freeroam__tile--selected' : 'freeroam__mode'}
                  aria-pressed={entry.id === activity?.id}
                  onClick={() => setSelected({ ...selected, activity: entry.id })}
                  onDoubleClick={() => entry.enabled && gotoActivity(entry.id)}
                >
                  <Icon name={(entry.icon ?? 'flag') as IconName} size={34} strokeWidth={1.8} />
                  <span className="freeroam__mode-text">
                    <span className="disp freeroam__mode-label">{t(entry.label)}</span>
                    {entry.tagline && <span className="muted freeroam__mode-tagline">{t(entry.tagline)}</span>}
                  </span>
                </button>
              ))}
          </main>

          {tab === 'weapons' && weapon && (
            <aside className="freeroam__preview">
              <div className="freeroam__preview-plate freeroam__plate--weapon">
                <Picture files={weaponFiles(weapon.weapon)} icon={weaponIcon(weapon.weapon)} size={84} />
              </div>
              <div className="freeroam__preview-heading">
                <h2 className="disp freeroam__preview-title">{t(weapon.label)}</h2>
                <span className="mono muted freeroam__preview-code">{weapon.weapon}</span>
              </div>
              <p className="freeroam__preview-text">{t('Gratuite, munitions infinies.')}</p>
              <button className="freeroam__action" onClick={() => takeWeapon(weapon.weapon)}>
                {t("Prendre l'arme")}
              </button>
              <div className="freeroam__owned">
                <h3 className="disp freeroam__owned-title">{t('Sur moi')}</h3>
                <div className="freeroam__chips">
                  {owned.map((entry) => (
                    <span key={entry.weapon} className="freeroam__chip">{t(entry.label)}</span>
                  ))}
                  {owned.length === 0 && <span className="muted freeroam__preview-text">{t('Aucune arme')}</span>}
                </div>
              </div>
              <button className="freeroam__danger" onClick={() => actions.freeroamAction('clearWeapons')}>
                {t('Retirer toutes les armes')}
              </button>
            </aside>
          )}

          {tab === 'vehicles' && vehicle && (
            <aside className="freeroam__preview">
              <div className="freeroam__preview-plate freeroam__plate--vehicle">
                <Picture files={[vehicle.model]} icon="vehicle" size={84} />
              </div>
              <div className="freeroam__preview-heading">
                <h2 className="disp freeroam__preview-title">{t(vehicle.label)}</h2>
                <span className="mono muted freeroam__preview-code">{vehicle.model}</span>
              </div>
              <p className="freeroam__preview-text">
                {t(vehicle.category)}. {t('Gratuit, ta custom suit le modèle.')}
              </p>
              <button className="freeroam__action" onClick={() => spawnVehicle(vehicle.model)}>
                {t('Faire apparaître')}
              </button>
              <div className="freeroam__tools">
                <button className="freeroam__tool" onClick={() => actions.freeroamAction('repair')}>
                  {t('Réparer')}
                </button>
                <button className="freeroam__tool" onClick={() => actions.freeroamAction('custom')}>
                  {t('Customiser')}
                </button>
              </div>
            </aside>
          )}

          {tab === 'activities' && activity && (
            <aside className="freeroam__preview">
              <div className="freeroam__preview-heading">
                <h2 className="disp freeroam__preview-title">{t(activity.label)}</h2>
                {activity.tagline && <span className="muted freeroam__preview-text">{t(activity.tagline)}</span>}
              </div>
              {activity.description && <p className="freeroam__preview-text">{t(activity.description)}</p>}
              <button className="freeroam__action" disabled={!activity.enabled} onClick={() => gotoActivity(activity.id)}>
                {activity.enabled ? t('Aller au PNJ') : t('Bientôt disponible')}
              </button>
            </aside>
          )}
        </div>
      </section>
    </div>
  );
}
