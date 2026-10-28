import { useEffect, useState } from 'react';
import { Icon } from '../components/icons/Icon';
import type { ChaseBoardRow } from '../types/game';

/** Contenu envoyé par Lua avec SendDuiMessage */
interface BoardData {
  rows: ChaseBoardRow[];
  size: number;
}

/** Exemple affiché dans le navigateur (npm run dev), hors du jeu */
const PREVIEW: BoardData = {
  size: 10,
  rows: [
    { name: 'Wezor', elo: 1184, wins: 14, losses: 4, draws: 1 },
    { name: 'Kaze', elo: 1121, wins: 11, losses: 6, draws: 0 },
    { name: 'Nyx', elo: 1076, wins: 8, losses: 5, draws: 2 },
    { name: 'Rook', elo: 1032, wins: 6, losses: 5, draws: 0 },
    { name: 'Vandal_LS', elo: 1004, wins: 3, losses: 3, draws: 1 },
    { name: 'Moreau', elo: 987, wins: 4, losses: 6, draws: 0 },
    { name: 'Tilt', elo: 951, wins: 2, losses: 5, draws: 1 },
  ],
};

const isBrowser = !('invokeNative' in window);

/** Classement ELO de la course poursuite, affiché sur l'écran de la zone safe. */
export function ChaseBoard() {
  const [data, setData] = useState<BoardData | null>(isBrowser ? PREVIEW : null);

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const payload = typeof event.data === 'string' ? safeParse(event.data) : event.data;
      if (payload && Array.isArray((payload as BoardData).rows)) setData(payload as BoardData);
    };
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, []);

  const rows = data?.rows ?? [];
  const size = data?.size ?? 10;
  const empty = Array.from({ length: Math.max(0, size - rows.length) });

  return (
    <div className="board">
      <header className="board__header">
        <span className="board__icon">
          <Icon name="trophy" size={44} strokeWidth={2} />
        </span>
        <span className="board__heading">
          <span className="mono board__eyebrow">Classement ELO</span>
          <span className="disp board__title">Course poursuite</span>
        </span>
        <span className="mono board__hint">PNJ à côté pour jouer</span>
      </header>

      <div className="board__columns mono">
        <span>#</span>
        <span>Joueur</span>
        <span>V / D / N</span>
        <span>ELO</span>
      </div>

      <ol className="board__rows">
        {rows.map((row, index) => (
          <li key={`${row.name}-${index}`} className={`board__row board__row--${index < 3 ? `top${index + 1}` : 'normal'}`}>
            <span className="disp board__rank">{index + 1}</span>
            <span className="board__name">{row.name}</span>
            <span className="mono board__record">
              {row.wins} / {row.losses} / {row.draws}
            </span>
            <span className="disp board__elo">{row.elo}</span>
          </li>
        ))}
        {empty.map((_, index) => (
          <li key={`empty-${index}`} className="board__row board__row--empty">
            <span className="disp board__rank">{rows.length + index + 1}</span>
            <span className="board__name">—</span>
            <span />
            <span />
          </li>
        ))}
      </ol>
    </div>
  );
}

function safeParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}
