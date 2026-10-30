import { useEffect, useState } from 'react';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CodCatalog, CodHudState, CodProfile, CodStateData } from '../../types/cod';
import type { PauseAction, PauseInfo } from '../../types/game';
import { LanguagePicker } from '../ui/LanguagePicker';
import { CodClassEditor } from './CodClassEditor';
import { CodScoreTable } from './CodHud';
import { StreaksTab } from './CodMenu';
import { CodOperator, formatTime, useSecondsLeft } from './CodParts';

type Tab = 'game' | 'classes' | 'streaks' | 'options';

interface CodPauseMenuProps {
  /** null : pas de partie (fin de partie, retour au menu en cours) */
  hud: CodHudState | null;
  live: CodStateData | null;
  profile: CodProfile | null;
  catalog: CodCatalog | null;
  onProfile: (profile: CodProfile) => void;
}

/** Menu pause (Échap) en partie : mêmes titre et onglets que le menu du mode, le combat continue derrière. */
export function CodPauseMenu({ hud, live, profile, catalog, onProfile }: CodPauseMenuProps) {
  useT();
  const { state, actions } = useGame();
  const info = state.pause.info;
  const [tab, setTab] = useState<Tab>('game');
  const tabs: { id: Tab; label: string; subtitle: string }[] = [
    { id: 'game', label: t('Partie'), subtitle: hud ? `${t(hud.map.label)} · ${t(hud.map.place)}` : 'Call of Duty' },
  ];
  if (profile && catalog) {
    tabs.push(
      { id: 'classes', label: t('Classes'), subtitle: t('S\'applique à ta prochaine apparition') },
      { id: 'streaks', label: t('Séries'), subtitle: t('Choisis tes séries d\'éliminations') },
    );
  }
  tabs.push({ id: 'options', label: t('Options'), subtitle: t('Touches et langue') });

  // Échap : retour à l'onglet de la partie, puis reprise du jeu
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      if (tab === 'game') actions.closePause();
      else setTab('game');
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [actions, tab]);

  if (!info) return null;
  return (
    <div className="cod-menu cod-pause">
      <header className="cod-menu__head">
        <div className="cod-menu__titles">
          <h1 className="cod-title">{hud ? t(hud.playlist.label) : t('Pause')}</h1>
          <span className="cod-subtitle">{tabs.find((entry) => entry.id === tab)?.subtitle}</span>
        </div>
        {profile && <CodOperator profile={profile} />}
      </header>

      <nav className="cod-tabs">
        {tabs.map((entry) => (
          <button
            key={entry.id}
            className={entry.id === tab ? 'cod-tab cod-tab--active' : 'cod-tab'}
            onClick={() => setTab(entry.id)}
          >
            {entry.label}
          </button>
        ))}
      </nav>

      <div className="cod-menu__body">
        {tab === 'game' && (
          <GameTab
            hud={hud}
            live={live}
            equipped={profile?.classes[profile.selected - 1]?.name}
            onClose={actions.closePause}
            onAction={actions.pauseAction}
            onClasses={profile && catalog ? () => setTab('classes') : undefined}
          />
        )}
        {tab === 'classes' && profile && catalog && <CodClassEditor profile={profile} catalog={catalog} onProfile={onProfile} />}
        {tab === 'streaks' && profile && catalog && <StreaksTab profile={profile} catalog={catalog} onProfile={onProfile} />}
        {tab === 'options' && <OptionsTab info={info} />}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Partie
// ---------------------------------------------------------------------------

interface Entry {
  id: string;
  label: string;
  hint?: string;
  danger?: boolean;
  /** espace au-dessus (sépare les sorties du reste) */
  gap?: boolean;
  run: () => void;
}

interface GameTabProps {
  hud: CodHudState | null;
  live: CodStateData | null;
  /** nom de la classe équipée */
  equipped?: string;
  onClose: () => void;
  onAction: (action: PauseAction) => void;
  onClasses?: () => void;
}

/** Actions à gauche, tableau des scores à droite. */
function GameTab({ hud, live, equipped, onClose, onAction, onClasses }: GameTabProps) {
  useT();
  const [selected, setSelected] = useState(0);
  const [confirming, setConfirming] = useState<PauseAction | null>(null);

  // Une sortie demande un second clic : la partie en cours serait perdue
  const exit = (action: PauseAction) => () => {
    if (confirming === action) onAction(action);
    else setConfirming(action);
  };
  const select = (index: number) => {
    if (index === selected) return;
    setSelected(index);
    setConfirming(null);
  };

  const entries: Entry[] = [{ id: 'resume', label: t('Reprendre'), hint: t('ÉCHAP'), run: onClose }];
  if (onClasses) entries.push({ id: 'classes', label: t('Changer de classe'), hint: equipped, run: onClasses });
  entries.push(
    { id: 'map', label: t('Carte'), run: () => onAction('map') },
    { id: 'settings', label: t('Paramètres'), run: () => onAction('settings') },
  );
  if (hud) {
    entries.push({
      id: 'codLeave',
      label: confirming === 'codLeave' ? t('Confirmer : quitter la partie') : t('Quitter la partie'),
      gap: true,
      run: exit('codLeave'),
    });
  }
  entries.push(
    {
      id: 'lobby',
      label: confirming === 'lobby' ? t('Confirmer : retour au lobby') : t('Retour au lobby'),
      gap: !hud,
      run: exit('lobby'),
    },
    {
      id: 'quit',
      label: confirming === 'quit' ? t('Confirmer : quitter') : t('Quitter'),
      danger: true,
      run: exit('quit'),
    },
  );

  // Flèches pour choisir, Entrée pour valider
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Enter') {
        // Sinon le bouton qui a le focus se déclencherait aussi
        event.preventDefault();
        return entries[selected]?.run();
      }
      if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return;
      event.preventDefault();
      const step = event.key === 'ArrowDown' ? 1 : -1;
      select((selected + step + entries.length) % entries.length);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  });

  return (
    <>
      <section className="cod-column">
        <ul className="cod-list">
          {entries.map((entry, index) => (
            <li key={entry.id} className={entry.gap ? 'cod-pause__gap' : undefined}>
              <button
                className={[
                  'cod-list__row cod-pause__entry',
                  index === selected && 'cod-list__row--active',
                  entry.danger && 'cod-pause__entry--danger',
                ].filter(Boolean).join(' ')}
                onMouseEnter={() => select(index)}
                onClick={entry.run}
              >
                <span>{entry.label}</span>
                {entry.hint && <span className="cod-list__meta">{entry.hint}</span>}
              </button>
            </li>
          ))}
        </ul>
      </section>

      {hud && live && (
        <section className="cod-pause__board">
          <header className="cod-board__head">
            <span className="cod-board__title">{t('Tableau des scores')}</span>
            <MatchClock hud={hud} live={live} />
          </header>
          <CodScoreTable board={live.board} team={hud.team} teams={hud.teams} scores={live.scores} />
        </section>
      )}
    </>
  );
}

function MatchClock({ hud, live }: { hud: CodHudState; live: CodStateData }) {
  const remainingAtStart = useSecondsLeft(hud.remaining, hud.at);
  return <span className="cod-corner__time">{formatTime(live.remaining ?? remainingAtStart)}</span>;
}

// ---------------------------------------------------------------------------
// Options
// ---------------------------------------------------------------------------

function OptionsTab({ info }: { info: PauseInfo }) {
  useT();
  const keys: [string, string][] = [
    [info.keys.menu, t('Tableau des scores (maintenir)')],
    [info.keys.codPrimary, t('Arme principale')],
    [info.keys.codSecondary, t('Arme secondaire')],
    [info.keys.codStreak, t('Utiliser une série')],
    [info.keys.codClass, t('Changer de classe')],
    ['E', t('Poser ou désamorcer la bombe (maintenir)')],
    [info.keys.chat, t('Chat (/commande pour une commande)')],
    ['/lobby', t('Retour au lobby')],
    ['/langue', t('Changer de langue')],
  ];
  return (
    <>
      <section className="cod-column">
        <span className="cod-label">{t('Touches principales')}</span>
        <ul className="cod-list">
          {keys.map(([key, action]) => (
            <li key={key} className="cod-pause__key">
              <span className="cod-key">{key}</span>
              <span>{action}</span>
            </li>
          ))}
        </ul>
        <p className="cod-text">{t('Les touches se changent dans Paramètres › Raccourcis clavier › FiveM.')}</p>
      </section>

      <section className="cod-column cod-column--right">
        <span className="cod-label">{t('Langue')}</span>
        <LanguagePicker />
      </section>
    </>
  );
}
