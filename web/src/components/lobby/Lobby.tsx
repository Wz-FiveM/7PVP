import { useCallback, useEffect, useState } from 'react';
import { useGame } from '../../store/GameContext';
import type { LobbyMode } from '../../types/game';
import { formatMoney } from '../../utils/format';
import { Logo } from '../ui/Logo';
import './lobby.css';

/** Couleur de chaque mode (classes zone-* de la D.A) */
const MODE_ACCENT: Record<string, string> = {
  pvp: 'zone-pvp',
  freeroam: 'zone-safe',
};

/** Points forts affichés dans le détail du mode */
const MODE_FEATURES: Record<string, string[]> = {
  pvp: ['Équipes de 4', 'Zombies et largages', 'Sac perdu à la mort', 'Classement de saison'],
  freeroam: ['Armes et véhicules gratuits', 'PvP au choix', 'Aucune perte'],
};

const playersLabel = (count: number) => `${count} joueur${count > 1 ? 's' : ''} en jeu`;

/** Écran de choix du mode, façon menu principal : modes à gauche, détail et déploiement à droite. */
export function Lobby() {
  const { state, actions } = useGame();
  const modes = state.lobby.modes;
  const player = state.player;
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [joining, setJoining] = useState(false);

  const selected = modes.find((mode) => mode.id === selectedId) ?? modes.find((mode) => mode.enabled) ?? modes[0];
  const online = modes.reduce((total, mode) => total + mode.players, 0);
  const progress = player ? ((player.xp % state.config.xpPerLevel) / state.config.xpPerLevel) * 100 : 0;

  const deploy = useCallback(async () => {
    if (!selected?.enabled || joining) return;
    setJoining(true);
    await actions.joinMode(selected.id);
    setJoining(false);
  }, [selected, joining, actions]);

  // Flèches pour choisir, Entrée pour se déployer
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Enter') return void deploy();
      if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return;
      const index = modes.findIndex((mode) => mode.id === selected?.id);
      const next = modes[(index + (event.key === 'ArrowDown' ? 1 : -1) + modes.length) % modes.length];
      if (next) setSelectedId(next.id);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [modes, selected, deploy]);

  return (
    <div className="lobby">
      <header className="lobby__bar">
        <Logo size={56} />
        <div className="lobby__brand">
          <span className="disp lobby__brand-name">7PVP</span>
          <span className="mono lobby__brand-meta">{playersLabel(online).toUpperCase()}</span>
        </div>
        {player && (
          <div className="lobby__operator">
            <div className="lobby__operator-text">
              <span className="disp lobby__operator-name">{player.name}</span>
              <span className="lobby__operator-level">
                <span className="disp">Niv. {player.level}</span>
                <span className="lobby__xp">
                  <span style={{ width: `${progress}%` }} />
                </span>
                <span className="mono">{formatMoney(player.money)}</span>
              </span>
            </div>
            <span className="disp lobby__operator-badge">{player.level}</span>
          </div>
        )}
      </header>

      <div className="lobby__body">
        <section className="lobby__list">
          <span className="mono lobby__eyebrow">Sélection du mode</span>
          <h1 className="disp lobby__title">Choisis ton déploiement</h1>
          <nav className="lobby__modes">
            {modes.map((mode) => (
              <ModeEntry
                key={mode.id}
                mode={mode}
                selected={mode.id === selected?.id}
                onSelect={() => setSelectedId(mode.id)}
                onDeploy={deploy}
              />
            ))}
          </nav>
        </section>

        {selected && (
          <section className={`lobby-detail ${MODE_ACCENT[selected.id] ?? 'zone-pvp'}`} key={selected.id}>
            <div className="stripes lobby-detail__stripes" />
            <span className="mono lobby-detail__tag">{selected.tagline}</span>
            <h2 className="disp lobby-detail__name">{selected.label}</h2>
            <p className="lobby-detail__description">{selected.description}</p>
            {MODE_FEATURES[selected.id] && (
              <ul className="lobby-detail__features">
                {MODE_FEATURES[selected.id].map((feature) => (
                  <li key={feature} className="mono lobby-detail__feature">{feature}</li>
                ))}
              </ul>
            )}
            <div className="lobby-detail__footer">
              <span className="mono lobby-detail__players">
                {selected.enabled ? playersLabel(selected.players).toUpperCase() : 'EN DÉVELOPPEMENT'}
              </span>
              <button
                className="btn btn--primary lobby-detail__deploy"
                disabled={!selected.enabled || joining}
                onClick={deploy}
              >
                {!selected.enabled ? 'Bientôt disponible' : joining ? 'Déploiement…' : 'Déployer'}
              </button>
            </div>
          </section>
        )}
      </div>

      <footer className="lobby__footer">
        <span className="lobby__key">
          <span className="mono keycap--solid">↑↓</span>
          Choisir
        </span>
        <span className="lobby__key">
          <span className="mono keycap--solid">ENTRÉE</span>
          Déployer
        </span>
        <span className="mono lobby__hint">Retour ici depuis une zone safe : menu [VERR. MAJ] ou /lobby</span>
      </footer>
    </div>
  );
}

interface ModeEntryProps {
  mode: LobbyMode;
  selected: boolean;
  onSelect: () => void;
  onDeploy: () => void;
}

function ModeEntry({ mode, selected, onSelect, onDeploy }: ModeEntryProps) {
  const classes = [
    'lobby-mode',
    MODE_ACCENT[mode.id] ?? 'zone-pvp',
    selected && 'lobby-mode--selected',
    !mode.enabled && 'lobby-mode--locked',
  ].filter(Boolean).join(' ');

  return (
    <button className={classes} onClick={onSelect} onDoubleClick={onDeploy} onMouseEnter={onSelect}>
      <span className="lobby-mode__marker" />
      <span className="lobby-mode__text">
        <span className="mono lobby-mode__tag">{mode.tagline}</span>
        <span className="disp lobby-mode__name">{mode.label}</span>
      </span>
      <span className="mono lobby-mode__players">{mode.enabled ? mode.players : 'BIENTÔT'}</span>
      <span className="lobby-mode__arrow">›</span>
    </button>
  );
}
