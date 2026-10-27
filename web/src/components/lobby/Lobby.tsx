import { useState } from 'react';
import { useGame } from '../../store/GameContext';
import type { LobbyMode } from '../../types/game';
import { Brackets } from '../ui/Brackets';
import { Logo } from '../ui/Logo';
import './lobby.css';

/** Couleur de chaque mode (classes zone-* de la D.A) */
const MODE_ACCENT: Record<string, string> = {
  pvp: 'zone-pvp',
  freeroam: 'zone-safe',
};

/** Écran de choix du mode, affiché à l'arrivée sur le serveur. */
export function Lobby() {
  const { state, actions } = useGame();
  const [joining, setJoining] = useState<string | null>(null);

  const join = async (mode: LobbyMode) => {
    if (!mode.enabled || joining) return;
    setJoining(mode.id);
    await actions.joinMode(mode.id);
    setJoining(null);
  };

  return (
    <div className="lobby">
      <div className="lobby__content">
        <header className="lobby__header">
          <Logo size={170} />
          <div className="lobby__titles">
            <span className="label">Bienvenue</span>
            <h1 className="disp lobby__title">Choisis ton mode</h1>
          </div>
        </header>

        <div className="lobby__modes">
          {state.lobby.modes.map((mode) => (
            <article
              key={mode.id}
              className={`lobby-card ${MODE_ACCENT[mode.id] ?? 'zone-pvp'} ${mode.enabled ? '' : 'lobby-card--locked'}`}
            >
              <div className="lobby-card__panel cut">
                <div className="stripes" />
                <div className="lobby-card__body">
                  <span className="label lobby-card__tagline">{mode.tagline}</span>
                  <h2 className="disp lobby-card__name">{mode.label}</h2>
                  <p className="lobby-card__description">{mode.description}</p>
                  <span className="mono muted lobby-card__players">
                    {mode.enabled ? `${mode.players} JOUEUR${mode.players > 1 ? 'S' : ''} EN JEU` : 'EN DÉVELOPPEMENT'}
                  </span>
                  <button
                    className={mode.enabled ? 'btn btn--primary cut-s lobby-card__join' : 'btn cut-s lobby-card__join'}
                    disabled={!mode.enabled || joining !== null}
                    onClick={() => join(mode)}
                  >
                    {!mode.enabled ? 'Bientôt disponible' : joining === mode.id ? 'Connexion…' : 'Rejoindre'}
                  </button>
                </div>
              </div>
              {mode.enabled && <Brackets />}
            </article>
          ))}
        </div>

        <p className="mono lobby__hint">
          TU POURRAS REVENIR ICI DEPUIS UNE ZONE SAFE : MENU [F2] OU COMMANDE /LOBBY
        </p>
      </div>
    </div>
  );
}
