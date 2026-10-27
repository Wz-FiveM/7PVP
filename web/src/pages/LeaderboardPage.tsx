import { useEffect } from 'react';
import { Panel, PanelHeader } from '../components/ui/Panel';
import { useGame } from '../store/GameContext';
import { formatKd } from '../utils/format';
import './pages.css';

export function LeaderboardPage() {
  const { state, actions } = useGame();

  useEffect(() => {
    actions.refreshLeaderboard();
  }, [actions]);

  return (
    <Panel>
      <PanelHeader title="Top 10" aside="TRIÉ PAR KILLS" />
      <table className="leaderboard">
        <thead>
          <tr>
            <th className="label">#</th>
            <th className="label">Joueur</th>
            <th className="label">Niveau</th>
            <th className="label">Kills</th>
            <th className="label">Morts</th>
            <th className="label">K/D</th>
            <th className="label">PNJ</th>
          </tr>
        </thead>
        <tbody>
          {state.leaderboard.map((row, i) => (
            <tr key={`${row.name}-${i}`} className={i < 3 ? 'leaderboard__row--top' : undefined}>
              <td className="mono leaderboard__rank">{String(i + 1).padStart(2, '0')}</td>
              <td className="leaderboard__name">
                {row.name}
                {row.online && <span className="leaderboard__online">En ligne</span>}
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
    </Panel>
  );
}
