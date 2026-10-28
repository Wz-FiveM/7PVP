import { useEffect, useState, type ReactNode } from 'react';
import { useGame } from '../../store/GameContext';
import type { PauseInfo } from '../../types/game';
import { formatKd } from '../../utils/format';
import { Icon, type IconName } from '../icons/Icon';
import { Logo } from '../ui/Logo';
import './pause.css';

type PauseTab = 'home' | 'controls';

const TABS: { id: PauseTab; label: string; icon: IconName }[] = [
  { id: 'home', label: 'Accueil', icon: 'profile' },
  { id: 'controls', label: 'Commandes', icon: 'help' },
];

const MODE_LABELS: Record<string, string> = { pvp: 'PvP', freeroam: 'Freeroam' };

/** Menu pause (Échap) : accès rapide à la carte, aux paramètres, au lobby et à la déconnexion. */
export function PauseMenu() {
  const { state, actions } = useGame();
  const info = state.pause.info;
  const [tab, setTab] = useState<PauseTab>('home');
  const [confirmQuit, setConfirmQuit] = useState(false);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') actions.closePause();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [actions]);

  if (!info) return null;
  const inPvp = info.mode === 'pvp';

  return (
    <div className="pause">
      <aside className="pause__panel">
        <div className="stripes pause__stripes" />
        <header className="pause__header">
          <Logo size={44} />
          <div className="pause__heading">
            <h1 className="disp pause__title">
              Menu <span className="pause__accent">pause</span>
            </h1>
            <span className="muted pause__subtitle">Accès rapide et informations de ton compte</span>
          </div>
          <button className="btn btn--small cut-s pause__close" onClick={actions.closePause} aria-label="Fermer">
            ✕
          </button>
        </header>

        <div className="pause__body">
          <nav className="pause__nav">
            {TABS.map((item) => (
              <button
                key={item.id}
                className={item.id === tab ? 'pause__tab pause__tab--active cut-s' : 'pause__tab cut-s'}
                onClick={() => setTab(item.id)}
              >
                <Icon name={item.icon} size={16} strokeWidth={2.2} />
                {item.label}
              </button>
            ))}
            <button className="pause__tab cut-s" onClick={() => actions.pauseAction('settings')}>
              <Icon name="craft" size={16} strokeWidth={2.2} />
              Paramètres
            </button>

            <div className="pause__nav-bottom">
              {info.mode && (
                <button className="pause__tab cut-s" onClick={() => actions.pauseAction('lobby')}>
                  <Icon name="exit" size={16} strokeWidth={2.2} />
                  Retour au lobby
                </button>
              )}
              <button
                className="pause__tab pause__tab--danger cut-s"
                onClick={() => (confirmQuit ? actions.pauseAction('quit') : setConfirmQuit(true))}
              >
                <Icon name="exit" size={16} strokeWidth={2.2} />
                {confirmQuit ? 'Confirmer' : 'Quitter'}
              </button>
            </div>
          </nav>

          <main className="pause__content">
            {tab === 'home' ? <PauseHome info={info} inPvp={inPvp} /> : <PauseControls info={info} />}
          </main>
        </div>
      </aside>
    </div>
  );
}

function PauseHome({ info, inPvp }: { info: PauseInfo; inPvp: boolean }) {
  const { actions } = useGame();

  return (
    <>
      <div className="pause__shortcuts">
        <PauseCard
          title="Carte"
          text="Ouvrir la carte du jeu"
          icon="flag"
          large
          onClick={() => actions.pauseAction('map')}
        />
        {inPvp && (
          <PauseCard
            title="Inventaire"
            text={`Menu ${info.keys.menu} : sac, groupe, boutique`}
            icon="inventory"
            onClick={() => actions.pauseAction('menu')}
          />
        )}
        <PauseCard
          title="Paramètres"
          text="Graphismes, son, commandes de GTA"
          icon="craft"
          onClick={() => actions.pauseAction('settings')}
        />
      </div>

      <PauseSection title="Mon compte" text="Informations sur ton personnage">
        <div className="pause__tiles">
          <PauseTile label="Personnage" value={info.name} icon="profile" />
          <PauseTile label="ID joueur" value={`#${info.serverId}`} icon="contract" />
          <PauseTile label="Mode" value={info.mode ? MODE_LABELS[info.mode] ?? info.mode : 'Lobby'} icon="crosshair" />
          <PauseTile label="Niveau" value={info.level} icon="trophy" />
          <PauseTile label="Kills / morts" value={`${info.kills} / ${info.deaths} · ${formatKd(info.kills, info.deaths)}`} icon="weapon" />
          <PauseTile label="Zombies tués" value={info.npcKills} icon="moon" />
        </div>
      </PauseSection>
    </>
  );
}

function PauseControls({ info }: { info: PauseInfo }) {
  const rows: [string, string][] = [
    [info.keys.menu, 'Menu : inventaire, groupe, profil, boutique'],
    [`${info.keys.hotbar} (maintenu)`, 'Afficher les raccourcis'],
    ['1 – 7', 'Utiliser un raccourci'],
    ['E', 'Ramasser un sac, fouiller un corps ou un largage'],
    [info.keys.chat, 'Chat (/commande pour une commande)'],
    ['/inviter ID', 'Inviter un joueur dans ton groupe'],
    ['/lobby', 'Retour au lobby (en zone safe)'],
    ['Échap', 'Menu pause'],
  ];
  if (info.isAdmin) {
    rows.push([info.keys.admin, 'Panneau admin'], [info.keys.noclip, 'Noclip'], ['/tpm', 'Téléportation au marqueur']);
  }

  return (
    <PauseSection title="Commandes" text="Les touches se changent dans Paramètres > Raccourcis clavier > FiveM">
      <ul className="pause__controls">
        {rows.map(([key, action]) => (
          <li key={key} className="pause__control">
            <span className="mono pause__key cut-s">{key}</span>
            <span>{action}</span>
          </li>
        ))}
      </ul>
    </PauseSection>
  );
}

function PauseSection({ title, text, children }: { title: string; text: string; children: ReactNode }) {
  return (
    <section className="pause__section">
      <h2 className="disp pause__section-title">
        <span className="pause__dot" />
        {title}
      </h2>
      <p className="muted pause__section-text">{text}</p>
      {children}
    </section>
  );
}

interface PauseCardProps {
  title: string;
  text: string;
  icon: IconName;
  large?: boolean;
  onClick: () => void;
}

function PauseCard({ title, text, icon, large, onClick }: PauseCardProps) {
  return (
    <button className={large ? 'pause__card pause__card--large cut' : 'pause__card cut'} onClick={onClick}>
      <Icon name={icon} size={large ? 26 : 20} strokeWidth={2} className="pause__card-icon" />
      <span className="disp pause__card-title">{title}</span>
      <span className="muted pause__card-text">{text}</span>
      <span className="pause__card-arrow">›</span>
    </button>
  );
}

function PauseTile({ label, value, icon }: { label: string; value: ReactNode; icon: IconName }) {
  return (
    <div className="pause__tile cut-s">
      <span className="pause__tile-icon cut-s">
        <Icon name={icon} size={16} strokeWidth={2.2} />
      </span>
      <span className="pause__tile-text">
        <span className="label pause__tile-label">{label}</span>
        <span className="pause__tile-value">{value}</span>
      </span>
    </div>
  );
}
