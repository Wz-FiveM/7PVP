import { useEffect, useState } from 'react';
import { crewApi } from '../api/crewApi';
import type { CrewBoardRow, LeaderboardScope } from '../types/game';
import { Panel, PanelHeader } from '../components/ui/Panel';
import { useT } from '../i18n';
import { useGame } from '../store/GameContext';
import { formatKd } from '../utils/format';
import './pages.css';

const SCOPES: { id: LeaderboardScope; label: string }[] = [
  { id: 'season', label: 'Saison en cours' },
  { id: 'previous', label: 'Saison précédente' },
  { id: 'all', label: 'De tous les temps' },
];

type Board = 'players' | 'crews';

const BOARDS: { id: Board; label: string }[] = [
  { id: 'players', label: 'Joueurs' },
  { id: 'crews', label: 'Crews' },
];

export function LeaderboardPage() {
  const t = useT();
  const [board, setBoard] = useState<Board>('players');
  const [scope, setScope] = useState<LeaderboardScope>('season');

  return (
    <Panel>
      <div className="leaderboard-tabs">
        {BOARDS.map((item) => (
          <button
            key={item.id}
            className={item.id === board ? 'btn btn--small btn--active cut-s' : 'btn btn--small cut-s'}
            onClick={() => setBoard(item.id)}
          >
            {t(item.label)}
          </button>
        ))}
        <span className="leaderboard-tabs__gap" />
        {SCOPES.map((item) => (
          <button
            key={item.id}
            className={item.id === scope ? 'btn btn--small btn--active cut-s' : 'btn btn--small cut-s'}
            onClick={() => setScope(item.id)}
          >
            {t(item.label)}
          </button>
        ))}
      </div>
      {board === 'players' ? <PlayerBoard scope={scope} /> : <CrewBoard scope={scope} />}
    </Panel>
  );
}

function PlayerBoard({ scope }: { scope: LeaderboardScope }) {
  const t = useT();
  const { state, actions } = useGame();

  useEffect(() => {
    actions.refreshLeaderboard(scope);
  }, [actions, scope]);

  return (
    <>
      <PanelHeader title={t('Top 10 · {title}', { title: state.leaderboardTitle })} aside={t('TRIÉ PAR KILLS')} />
      <table className="leaderboard">
        <thead>
          <tr>
            <th className="label">#</th>
            <th className="label">{t('Joueur')}</th>
            <th className="label">{t('Niveau')}</th>
            <th className="label">{t('Kills')}</th>
            <th className="label">{t('Morts')}</th>
            <th className="label">K/D</th>
            <th className="label">{t('PNJ')}</th>
          </tr>
        </thead>
        <tbody>
          {state.leaderboard.map((row, i) => (
            <tr key={`${row.name}-${i}`} className={i < 3 ? 'leaderboard__row--top' : undefined}>
              <td className="mono leaderboard__rank">{String(i + 1).padStart(2, '0')}</td>
              <td className="leaderboard__name">
                {row.name}
                {row.online && <span className="leaderboard__online">{t('En ligne')}</span>}
              </td>
              <td className="mono">{row.level}</td>
              <td className="mono">{row.kills}</td>
              <td className="mono">{row.deaths}</td>
              <td className="mono">{formatKd(row.kills, row.deaths)}</td>
              <td className="mono">{row.npcKills}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {state.leaderboard.length === 0 && <p className="muted leaderboard__empty">{t('Aucun joueur classé pour l\'instant.')}</p>}
    </>
  );
}

/** Classement des crews : kills faits une fois dans le crew et territoires pris. */
function CrewBoard({ scope }: { scope: LeaderboardScope }) {
  const t = useT();
  const { state } = useGame();
  const [rows, setRows] = useState<CrewBoardRow[]>([]);
  const [title, setTitle] = useState('');

  useEffect(() => {
    let current = true;
    crewApi.leaderboard(scope).then((result) => {
      if (!current) return;
      setRows(Array.isArray(result?.rows) ? result.rows : []);
      setTitle(result?.title ?? '');
    });
    return () => {
      current = false;
    };
  }, [scope]);

  return (
    <>
      <PanelHeader title={t('Top 10 · {title}', { title })} aside={t('TRIÉ PAR SCORE')} />
      <table className="leaderboard">
        <thead>
          <tr>
            <th className="label">#</th>
            <th className="label">{t('Crew')}</th>
            <th className="label">{t('Score')}</th>
            <th className="label">{t('Kills')}</th>
            <th className="label">{t('Morts')}</th>
            <th className="label">K/D</th>
            <th className="label">{t('Prises')}</th>
            <th className="label">{t('Territoires')}</th>
            <th className="label">{t('Membres')}</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr key={row.tag} className={i < 3 ? 'leaderboard__row--top' : undefined}>
              <td className="mono leaderboard__rank">{String(i + 1).padStart(2, '0')}</td>
              <td className="leaderboard__name">
                [{row.tag}] {row.name}
                {state.crew?.tag === row.tag && <span className="leaderboard__online">{t('Ton crew')}</span>}
              </td>
              <td className="mono">{row.score}</td>
              <td className="mono">{row.kills}</td>
              <td className="mono">{row.deaths}</td>
              <td className="mono">{formatKd(row.kills, row.deaths)}</td>
              <td className="mono">{row.captures}</td>
              <td className="mono">{row.territories === false ? '—' : row.territories}</td>
              <td className="mono">{row.members}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {rows.length === 0 && <p className="muted leaderboard__empty">{t('Aucun crew classé pour l\'instant.')}</p>}
    </>
  );
}
