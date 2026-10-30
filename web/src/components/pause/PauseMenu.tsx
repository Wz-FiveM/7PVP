import { useEffect, useState } from 'react';
import { formatNumber, t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { PauseAction, PauseInfo } from '../../types/game';
import { formatKd } from '../../utils/format';
import { Icon } from '../icons/Icon';
import { Avatar } from '../ui/Avatar';
import { LanguagePicker } from '../ui/LanguagePicker';
import './pause.css';

const MODE_LABELS: Record<string, string> = { pvp: 'PvP', freeroam: 'Freeroam' };

interface Entry {
  id: string;
  label: string;
  hint?: string;
  danger?: boolean;
  /** espace au-dessus (sépare le retour au lobby et la déconnexion) */
  gap?: boolean;
  run: () => void;
}

/** Menu pause (Échap) : actions à gauche, compte et touches à droite, le jeu reste visible derrière. Call of Duty a le sien (CodPauseMenu). */
export function PauseMenu() {
  useT();
  const { state, actions } = useGame();
  const info = state.pause.info;
  const [selected, setSelected] = useState(0);
  const [confirmQuit, setConfirmQuit] = useState(false);

  const entries = info ? buildEntries(info, confirmQuit, {
    close: actions.closePause,
    run: (action: PauseAction) => actions.pauseAction(action),
    askQuit: () => setConfirmQuit(true),
  }) : [];

  // Échap ferme ; flèches pour choisir, Entrée pour valider
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') return actions.closePause();
      if (event.key === 'Enter') return entries[selected]?.run();
      if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return;
      event.preventDefault();
      const step = event.key === 'ArrowDown' ? 1 : -1;
      setSelected((index) => (index + step + entries.length) % entries.length);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [actions, entries, selected]);

  if (!info) return null;
  const player = state.player;
  const xpPerLevel = state.config.xpPerLevel || 1;
  const xp = player ? player.xp % xpPerLevel : 0;
  const mode = info.mode ? MODE_LABELS[info.mode] ?? info.mode : t('Lobby');

  return (
    <div className="pause">
      <aside className="pause__side">
        <header className="pause__heading">
          <span className="mono pause__eyebrow">7PVP · {mode.toUpperCase()} · ID #{info.serverId}</span>
          <h1 className="disp pause__title">{t('Pause')}</h1>
        </header>

        <nav className="pause__nav">
          {entries.map((entry, index) => (
            <button
              key={entry.id}
              className={[
                'pause__entry',
                index === selected && 'pause__entry--selected',
                entry.danger && 'pause__entry--danger',
                entry.gap && 'pause__entry--gap',
              ].filter(Boolean).join(' ')}
              onMouseEnter={() => setSelected(index)}
              onClick={entry.run}
            >
              <span className="disp pause__entry-label">{entry.label}</span>
              {entry.hint && <span className="mono pause__entry-hint">{entry.hint}</span>}
            </button>
          ))}
        </nav>
      </aside>

      <main className="pause__main">
        <section className="pause__operator">
          <span className="pause__avatar">
            <Avatar src={info.avatar} fallback={<Icon name="profile" size={56} strokeWidth={1.5} />} />
          </span>
          <div className="pause__operator-text">
            <span className="mono pause__label">{t('OPÉRATEUR')} · ID #{info.serverId}</span>
            <span className="disp pause__name">{info.name}</span>
            <div className="pause__level">
              <span className="disp pause__level-value">{t('NIV. {level}', { level: info.level })}</span>
              <span className="pause__xp">
                <span style={{ width: `${(xp / xpPerLevel) * 100}%` }} />
              </span>
              <span className="mono pause__xp-text">
                {formatNumber(xp)} / {formatNumber(xpPerLevel)} XP
              </span>
            </div>
          </div>
        </section>

        <div className="pause__stats">
          <Stat label={t('ÉLIMINATIONS')} value={formatNumber(info.kills)} tone="signal" />
          <Stat label={t('MORTS')} value={formatNumber(info.deaths)} />
          <Stat label={t('RATIO')} value={formatKd(info.kills, info.deaths)} />
          <Stat label={t('ZOMBIES')} value={formatNumber(info.npcKills)} tone="toxine" />
        </div>

        <section className="pause__keys">
          <h2 className="disp pause__keys-title">{t('Touches principales')}</h2>
          <ul className="pause__key-list">
            {buildKeys(info).map(([key, action]) => (
              <li key={key} className="pause__key-row">
                <span className="mono pause__key">{key}</span>
                <span>{action}</span>
              </li>
            ))}
          </ul>
          <p className="pause__keys-note">{t('Les touches se changent dans Paramètres › Raccourcis clavier › FiveM.')}</p>
        </section>

        <section className="pause__keys">
          <h2 className="disp pause__keys-title">{t('Langue')}</h2>
          <LanguagePicker />
        </section>
      </main>
    </div>
  );
}

function buildEntries(
  info: PauseInfo,
  confirmQuit: boolean,
  on: { close: () => void; run: (action: PauseAction) => void; askQuit: () => void },
): Entry[] {
  const inPvp = info.mode === 'pvp';
  const entries: Entry[] = [
    { id: 'resume', label: t('Reprendre'), hint: t('ÉCHAP'), run: on.close },
    { id: 'map', label: t('Carte'), run: () => on.run('map') },
  ];
  if (info.mode) {
    entries.push({
      id: 'menu',
      label: inPvp ? t('Équipement') : t('Menu Freeroam'),
      hint: info.keys.menu,
      run: () => on.run('menu'),
    });
  }
  if (inPvp) entries.push({ id: 'teleport', label: t('Téléportation'), hint: info.keys.teleport, run: () => on.run('teleport') });
  entries.push({ id: 'settings', label: t('Paramètres'), run: () => on.run('settings') });
  if (info.mode) entries.push({ id: 'lobby', label: t('Retour au lobby'), gap: true, run: () => on.run('lobby') });
  entries.push({
    id: 'quit',
    label: confirmQuit ? t('Confirmer : quitter') : t('Quitter'),
    danger: true,
    gap: !info.mode,
    run: () => (confirmQuit ? on.run('quit') : on.askQuit()),
  });
  return entries;
}

function buildKeys(info: PauseInfo): [string, string][] {
  const keys: [string, string][] = [
    [info.keys.menu, t('Équipement, équipe, boutique')],
    ['1 – 7', t('Raccourcis (la barre s\'affiche)')],
    ['ALT', t('Menu d\'interaction (maintenir)')],
    [info.keys.teleport, t('Téléportation entre zones safe')],
    ['E', t('Fouiller, parler, ramasser')],
    [info.keys.chat, t('Chat (/commande pour une commande)')],
    ['K', t('Ranger son véhicule (au volant)')],
    ['/lobby', t('Retour au lobby (en zone safe)')],
    ['/langue', t('Changer de langue')],
  ];
  if (info.isAdmin) {
    keys.push(
      [info.keys.admin, t('Panneau admin')],
      [info.keys.noclip, 'Noclip'],
      ['/tpm', t('Téléportation au marqueur')],
      ['/heure 22', t('Heure du jeu (/heure reset)')],
    );
  }
  return keys;
}

function Stat({ label, value, tone }: { label: string; value: string; tone?: 'signal' | 'toxine' }) {
  return (
    <div className={tone ? `pause__stat pause__stat--${tone}` : 'pause__stat'}>
      <span className="mono pause__label">{label}</span>
      <span className="disp pause__stat-value">{value}</span>
    </div>
  );
}
