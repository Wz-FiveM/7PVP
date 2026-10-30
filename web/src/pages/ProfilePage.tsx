import { Panel } from '../components/ui/Panel';
import { SegmentBar } from '../components/ui/SegmentBar';
import { formatNumber, useT } from '../i18n';
import { useGame } from '../store/GameContext';
import { formatKd, formatMoney, formatPoints } from '../utils/format';
import './pages.css';

export function ProfilePage() {
  const t = useT();
  const { state } = useGame();
  const { player, config } = state;
  if (!player) return null;

  const levelXp = player.xp % config.xpPerLevel;
  const season = player.season;
  const stats: [string, string | number][] = [
    [t('Kills'), player.kills],
    [t('Morts'), player.deaths],
    ['K/D', formatKd(player.kills, player.deaths)],
    [t('Zombies tués'), player.npcKills],
    [t('Argent total'), formatMoney(player.money)],
    [
      t(config.shopPoints?.label ?? 'Points boutique'),
      formatPoints(player.shopPoints ?? 0, config.shopPoints?.short ? t(config.shopPoints.short) : undefined),
    ],
    [t('XP totale'), formatNumber(player.xp)],
  ];
  if (season) {
    stats.push(
      [`${season.label} · ${t('kills')}`, season.kills],
      [`${season.label} · K/D`, formatKd(season.kills, season.deaths)],
      [`${season.label} · ${t('zombies')}`, season.npcKills],
    );
  }

  return (
    <div className="profile">
      <Panel className="profile__card">
        <span className="label">{t('Opérateur')}</span>
        <span className="disp profile__name">{player.name}</span>
        <span className="disp profile__level">{t('Niveau {level}', { level: player.level })}</span>
        <SegmentBar value={levelXp} max={config.xpPerLevel} segments={20} color="var(--signal)" height={8} />
        <span className="mono muted profile__xp">
          {t('{xp} / {max} XP avant le niveau {level}', { xp: levelXp, max: config.xpPerLevel, level: player.level + 1 })}
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
