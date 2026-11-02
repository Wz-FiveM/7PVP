import { gameApi } from '../api/gameApi';
import { Panel } from '../components/ui/Panel';
import { SegmentBar } from '../components/ui/SegmentBar';
import { formatNumber, useT } from '../i18n';
import { useGame } from '../store/GameContext';
import { formatKd, formatMoney, formatPoints } from '../utils/format';
import './pages.css';

/** Choix de la couleur du nom, en PvP : gamertags et killfeed. */
function NameColorPicker() {
  const t = useT();
  const { state, actions } = useGame();
  const current = state.player?.nameColor ?? null;

  const select = (id: string | null) => {
    gameApi.selectNameColor(id).then((result) => {
      if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    });
  };

  return (
    <div className="name-colors">
      <span className="label">{t('Couleur du nom')}</span>
      <div className="name-colors__list">
        <button
          className={current === null ? 'name-color name-color--default name-color--on cut-s' : 'name-color name-color--default cut-s'}
          title={t('Par défaut')}
          aria-label={t('Par défaut')}
          aria-pressed={current === null}
          onClick={() => select(null)}
        />
        {state.config.nameColors?.map((color) => (
          <button
            key={color.id}
            className={current === color.id ? 'name-color name-color--on cut-s' : 'name-color cut-s'}
            style={{ background: color.hex }}
            title={t(color.label)}
            aria-label={t(color.label)}
            aria-pressed={current === color.id}
            onClick={() => select(color.id)}
          />
        ))}
      </div>
      <span className="muted name-colors__hint">{t('Visible sur ton gamertag et dans le killfeed en PvP.')}</span>
    </div>
  );
}

export function ProfilePage() {
  const t = useT();
  const { state } = useGame();
  const { player, config } = state;
  if (!player) return null;

  const pvp = state.mode === 'pvp';
  const nameColor = pvp ? config.nameColors?.find((color) => color.id === player.nameColor)?.hex : undefined;
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
        <span className="disp profile__name" style={nameColor ? { color: nameColor } : undefined}>
          {player.displayName ?? player.name}
        </span>
        <span className="disp profile__level">{t('Niveau {level}', { level: player.level })}</span>
        <SegmentBar value={levelXp} max={config.xpPerLevel} segments={20} color="var(--signal)" height={8} />
        <span className="mono muted profile__xp">
          {t('{xp} / {max} XP avant le niveau {level}', { xp: levelXp, max: config.xpPerLevel, level: player.level + 1 })}
        </span>
        {pvp && <NameColorPicker />}
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
