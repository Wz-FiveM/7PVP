import { useEffect, useState } from 'react';
import type { LeaderboardScope } from '../types/game';
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

export function LeaderboardPage() {
  const t = useT();
  const { state, actions } = useGame();
  const [scope, setScope] = useState<LeaderboardScope>('season');

  useEffect(() => {
    actions.refreshLeaderboard(scope);
  }, [actions, scope]);

  return (
    <Panel>
      <div className="leaderboard-tabs">
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
    </Panel>
  );
}
