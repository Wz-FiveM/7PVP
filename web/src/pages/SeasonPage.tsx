import { gameApi } from '../api/gameApi';
import { Panel } from '../components/ui/Panel';
import { SegmentBar } from '../components/ui/SegmentBar';
import { useT } from '../i18n';
import { useGame } from '../store/GameContext';
import type { SeasonPassReward } from '../types/game';
import type { ActionResult } from '../types/nui';
import { formatMoney, formatPoints } from '../utils/format';
import { entriesOf, itemLabel } from '../utils/inventory';
import './pages.css';

/** Passe de saison : paliers gratuits et premium, et récompenses du classement à la fin du mois. */
export function SeasonPage() {
  const t = useT();
  const { state, actions } = useGame();
  const { config, player } = state;
  const pass = player?.seasonPass;
  const settings = config.seasonPass;
  if (!pass || !settings) return null;

  const report = (result: ActionResult | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };
  const short = config.shopPoints?.short ? t(config.shopPoints.short) : undefined;
  const maxTier = settings.tiers.length;
  const progress = pass.tier >= maxTier ? settings.pointsPerTier : pass.points % settings.pointsPerTier;

  const describe = (reward: SeasonPassReward): string => {
    const parts: string[] = [];
    if (reward.money) parts.push(formatMoney(reward.money));
    if (reward.xp) parts.push(`${reward.xp} XP`);
    if (reward.items) parts.push(...entriesOf(reward.items).map(([name, count]) => `${count} x ${itemLabel(config, name)}`));
    if (reward.title) parts.push(t('Titre : {title}', { title: t(reward.title) }));
    return parts.join(' · ');
  };

  const cell = (tier: number, reward: SeasonPassReward, premium: boolean) => {
    const claimed = Boolean(pass.claimed?.[`${premium ? 'p' : 'f'}${tier}`]);
    const reached = tier <= pass.tier;
    return (
      <div className="season-cell">
        <span className="season-cell__text">{describe(reward)}</span>
        <button
          className={claimed ? 'btn btn--small cut-s' : 'btn btn--primary btn--small cut-s'}
          disabled={claimed || !reached || (premium && !pass.premium)}
          onClick={() => gameApi.seasonPassClaim(tier, premium).then(report)}
        >
          {claimed ? t('Pris') : t('Prendre')}
        </button>
      </div>
    );
  };

  return (
    <div className="contracts">
      <Panel className="contract">
        <div className="contract__head">
          <span className="disp contract__label">{player?.season?.label ?? t('Saison')}</span>
          <span className="mono contract__reward">{t('Palier {tier} / {max}', { tier: pass.tier, max: maxTier })}</span>
        </div>
        <SegmentBar value={progress} max={settings.pointsPerTier} segments={20} color="var(--signal)" height={8} />
        <span className="muted">{t('Tu gagnes des points de passe en jouant : kills, assistances, contrats, largages, territoires...')}</span>
        {!pass.premium && (
          <button
            className="btn btn--primary btn--small cut-s"
            disabled={(player?.shopPoints ?? 0) < settings.premiumPrice}
            onClick={() => gameApi.seasonPassBuy().then(report)}
          >
            {t('Passe premium : {price}', { price: formatPoints(settings.premiumPrice, short) })}
          </button>
        )}
      </Panel>

      <Panel className="contract">
        <span className="disp contract__label">{t('Fin de saison')}</span>
        {config.seasonRewards?.map((rank) => (
          <span key={rank.id} className="muted">
            {rank.from === rank.to ? `${rank.from}` : `${rank.from}-${rank.to}`} : {t(rank.title)} · {formatPoints(rank.points, short)}
          </span>
        ))}
        <span className="muted">{t('Classement par kills de la saison, au moins {kills} kills.', { kills: config.seasonRewardsMinKills ?? 0 })}</span>
      </Panel>

      <div className="season-track">
        <span className="label">{t('Palier')}</span>
        <span className="label">{t('Gratuit')}</span>
        <span className="label">{t('Premium')}</span>
        {settings.tiers.map((entry, index) => {
          const tier = index + 1;
          return (
            <div key={tier} className={tier <= pass.tier ? 'season-track__row season-track__row--reached' : 'season-track__row'}>
              <span className="mono season-track__tier">{tier}</span>
              {cell(tier, entry.free, false)}
              {cell(tier, entry.premium, true)}
            </div>
          );
        })}
      </div>
    </div>
  );
}
