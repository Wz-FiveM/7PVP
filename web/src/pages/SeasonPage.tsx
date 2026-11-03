import { useState } from 'react';
import { gameApi } from '../api/gameApi';
import { Icon } from '../components/icons/Icon';
import { ItemIcon } from '../components/inventory/ItemIcon';
import { Panel } from '../components/ui/Panel';
import { useT } from '../i18n';
import { useGame } from '../store/GameContext';
import type { SeasonPassReward } from '../types/game';
import type { ActionResult } from '../types/nui';
import { formatMoney, formatPoints } from '../utils/format';
import { entriesOf, itemLabel } from '../utils/inventory';
import './pages.css';

/** Paliers affichés à la fois ; les flèches passent aux suivants. */
const VISIBLE = 6;

/** Passe de saison : paliers gratuits et premium en colonnes, et récompenses du classement à la fin du mois. */
export function SeasonPage() {
  const t = useT();
  const { state, actions } = useGame();
  const { config, player } = state;
  const pass = player?.seasonPass;
  const settings = config.seasonPass;
  const maxTier = settings?.tiers.length ?? 0;
  // Ouvre sur la page du palier en cours
  const [start, setStart] = useState(() => Math.floor(Math.max(0, Math.min(pass?.tier ?? 0, maxTier) - 1) / VISIBLE) * VISIBLE);
  if (!pass || !settings) return null;

  const report = (result: ActionResult | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };
  const short = config.shopPoints?.short ? t(config.shopPoints.short) : undefined;
  const done = pass.tier >= maxTier;
  const progress = done ? settings.pointsPerTier : pass.points % settings.pointsPerTier;
  const lastStart = Math.max(0, Math.ceil(maxTier / VISIBLE) * VISIBLE - VISIBLE);
  const shown = settings.tiers.slice(start, start + VISIBLE);

  /** Récompense mise en avant sur la carte (image et étiquette), le reste en petit dessous. */
  const card = (tier: number, reward: SeasonPassReward, premium: boolean) => {
    const items = entriesOf(reward.items);
    const [mainItem, mainCount] = items[0] ?? [];
    const rest: string[] = [];
    let visual;
    let label: string;
    if (mainItem) {
      const item = config.items[mainItem];
      visual = <ItemIcon name={mainItem} type={item?.type ?? 'material'} />;
      label = `${mainCount} x ${itemLabel(config, mainItem)}`;
      rest.push(...items.slice(1).map(([name, count]) => `${count} x ${itemLabel(config, name)}`));
      if (reward.money) rest.push(formatMoney(reward.money));
    } else if (reward.title) {
      visual = <span className="season-card__glyph"><Icon name="trophy" size={48} strokeWidth={1.3} /></span>;
      label = t(reward.title);
      if (reward.money) rest.push(formatMoney(reward.money));
    } else {
      visual = <ItemIcon name="money" type="money" />;
      label = reward.money ? formatMoney(reward.money) : `${reward.xp ?? 0} XP`;
    }
    if (reward.xp && (mainItem || reward.title || reward.money)) rest.push(`${reward.xp} XP`);
    if (mainItem && reward.title) rest.push(t('Titre : {title}', { title: t(reward.title) }));

    const claimed = Boolean(pass.claimed?.[`${premium ? 'p' : 'f'}${tier}`]);
    const reached = tier <= pass.tier;
    const locked = premium && !pass.premium;
    const claimable = reached && !claimed && !locked;
    const classes = ['season-card', claimed && 'season-card--claimed', claimable && 'season-card--ready', !reached && 'season-card--far']
      .filter(Boolean)
      .join(' ');

    return (
      <div className={classes}>
        <div className="season-card__visual">{visual}</div>
        <span className="season-card__tag">{label}</span>
        <span className="season-card__rest">{rest.join(' · ')}</span>
        <div className="season-card__foot">
          {claimed ? (
            <span className="season-card__state season-card__state--done">
              <Icon name="check" size={14} /> {t('Pris')}
            </span>
          ) : claimable ? (
            <button className="btn btn--primary btn--small cut-s" onClick={() => gameApi.seasonPassClaim(tier, premium).then(report)}>
              {t('Prendre')}
            </button>
          ) : (
            <span className="season-card__state">
              <Icon name="lock" size={14} /> {locked ? t('Premium') : t('Palier {tier}', { tier })}
            </span>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="contracts">
      <div className="season-head">
        <div className="season-head__stat">
          <span className="disp season-head__label">{t('Palier actif')}</span>
          <span className="disp season-head__box">{pass.tier}</span>
          <span className="muted mono">/ {maxTier}</span>
        </div>
        <span className="disp season-head__title">{player?.season?.label ?? t('Saison')}</span>
        <div className="season-head__stat">
          <span className="disp season-head__label">{t('Progression du palier')}</span>
          <span className="disp season-head__box">
            {progress} / {settings.pointsPerTier}
          </span>
          <span className="disp season-head__label">{t('points')}</span>
        </div>
      </div>

      <div className="season-board">
        <button className="season-board__arrow" disabled={start <= 0} onClick={() => setStart((value) => Math.max(0, value - VISIBLE))}>
          <svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" strokeWidth="2.5">
            <path d="M15 4l-8 8 8 8" />
          </svg>
        </button>

        <div className="season-board__grid">
          <span />
          {shown.map((_, index) => {
            const tier = start + index + 1;
            const classes = ['season-board__tier', tier <= pass.tier && 'season-board__tier--reached', tier === pass.tier && 'season-board__tier--current']
              .filter(Boolean)
              .join(' ');
            return (
              <span key={tier} className={`mono ${classes}`}>
                {tier}
              </span>
            );
          })}

          <span className="season-board__side">{t('Gratuit')}</span>
          {shown.map((entry, index) => (
            <div key={`f${start + index}`}>{card(start + index + 1, entry.free, false)}</div>
          ))}

          <span className="season-board__side season-board__side--premium">{t('Premium')}</span>
          {shown.map((entry, index) => (
            <div key={`p${start + index}`}>{card(start + index + 1, entry.premium, true)}</div>
          ))}
        </div>

        <button className="season-board__arrow" disabled={start >= lastStart} onClick={() => setStart((value) => Math.min(lastStart, value + VISIBLE))}>
          <svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" strokeWidth="2.5">
            <path d="M9 4l8 8-8 8" />
          </svg>
        </button>
      </div>

      <div className="season-foot">
        {pass.premium ? (
          <span className="season-foot__owned">
            <Icon name="gem" size={16} /> {t('Passe premium activé pour cette saison.')}
          </span>
        ) : (
          <button
            className="btn cut-s"
            disabled={(player?.shopPoints ?? 0) < settings.premiumPrice}
            onClick={() => gameApi.seasonPassBuy().then(report)}
          >
            {t('Passe premium : {price}', { price: formatPoints(settings.premiumPrice, short) })}
          </button>
        )}
        <span className="muted">{t('Tu gagnes des points de passe en jouant : kills, assistances, contrats, largages, territoires...')}</span>
      </div>

      <Panel className="contract">
        <span className="disp contract__label">{t('Fin de saison')}</span>
        {config.seasonRewards?.map((rank) => (
          <span key={rank.id} className="muted">
            {rank.from === rank.to ? `${rank.from}` : `${rank.from}-${rank.to}`} : {t(rank.title)} · {formatPoints(rank.points, short)}
          </span>
        ))}
        <span className="muted">{t('Classement par kills de la saison, au moins {kills} kills.', { kills: config.seasonRewardsMinKills ?? 0 })}</span>
      </Panel>
    </div>
  );
}
