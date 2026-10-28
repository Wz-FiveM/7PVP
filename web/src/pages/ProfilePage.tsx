import { Panel } from '../components/ui/Panel';
import { SegmentBar } from '../components/ui/SegmentBar';
import { useGame } from '../store/GameContext';
import { formatKd, formatMoney } from '../utils/format';
import './pages.css';

export function ProfilePage() {
  const { state } = useGame();
  const { player, config } = state;
  if (!player) return null;

  const levelXp = player.xp % config.xpPerLevel;
  const season = player.season;
  const stats: [string, string | number][] = [
    ['Kills', player.kills],
    ['Morts', player.deaths],
    ['K/D', formatKd(player.kills, player.deaths)],
    ['Zombies tués', player.npcKills],
    ['Argent total', formatMoney(player.money)],
    ['XP totale', player.xp.toLocaleString('fr-FR')],
  ];
  if (season) {
    stats.push(
      [`${season.label} · kills`, season.kills],
      [`${season.label} · K/D`, formatKd(season.kills, season.deaths)],
      [`${season.label} · zombies`, season.npcKills],
    );
  }

  return (
    <div className="profile">
      <Panel className="profile__card">
        <span className="label">Opérateur</span>
        <span className="disp profile__name">{player.name}</span>
        <span className="disp profile__level">Niveau {player.level}</span>
        <SegmentBar value={levelXp} max={config.xpPerLevel} segments={20} color="var(--signal)" height={8} />
        <span className="mono muted profile__xp">
          {levelXp} / {config.xpPerLevel} XP avant le niveau {player.level + 1}
        </span>
      </Panel>

      <div className="stat-grid">
        {stats.map(([label, value]) => (
          <Panel key={label} className="stat">
            <span className="label">{label}</span>
            <span className="mono stat__value">{value}</span>
          </Panel>
        ))}
      </div>
    </div>
  );
}
