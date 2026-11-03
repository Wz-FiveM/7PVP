import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { crewApi } from '../../api/crewApi';
import { formatNumber, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CrewBonusEntry, CrewData } from '../../types/game';
import type { ActionResult } from '../../types/nui';
import { entriesOf, itemLabel } from '../../utils/inventory';
import { formatLogDate } from '../inventory/CrewStashSection';
import { Panel } from '../ui/Panel';

const TICK_MS = 15000;

interface BonusRowProps {
  name: string;
  state: ReactNode;
  info: string;
  locked?: boolean;
  /** bouton d'achat, absent pour qui ne dépense pas */
  action?: ReactNode;
}

/** Ligne d'achat : nom et état, détail en dessous, bouton à droite. */
function BonusRow({ name, state, info, locked, action }: BonusRowProps) {
  return (
    <li className={locked ? 'crew-bonus__row crew-bonus__row--locked' : 'crew-bonus__row'}>
      <span className="crew-bonus__title">
        <span className="crew-bonus__name">{name}</span>
        <span className="crew-bonus__state">{state}</span>
      </span>
      <span className="mono crew-bonus__next">{info}</span>
      {action ?? <span />}
    </li>
  );
}

/**
 * Points de crew : solde commun, agrandissement du coffre, armurerie et historique des dépenses.
 * Tout le monde voit le solde, seuls le chef et les officiers dépensent (le serveur vérifie tout).
 */
export function CrewBonusPanel({ crew, canManage }: { crew: CrewData; canManage: boolean }) {
  const t = useT();
  const { state, actions } = useGame();
  const settings = state.config.crew?.bonus;
  const bonus = crew.bonus;
  const [now, setNow] = useState(() => Date.now());
  // buyIn est compté au moment de l'envoi du crew : le décompte repart de là
  const syncedAt = useMemo(() => Date.now(), [bonus]);

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), TICK_MS);
    return () => window.clearInterval(timer);
  }, []);

  if (!settings || !bonus) return null;

  const report = (result: ActionResult | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };
  const buyButton = (disabled: boolean, onClick: () => Promise<ActionResult | undefined>, primary = false) =>
    canManage ? (
      <button className={primary ? 'btn btn--primary btn--small cut-s' : 'btn btn--small cut-s'} disabled={disabled} onClick={() => onClick().then(report)}>
        {t('Acheter')}
      </button>
    ) : undefined;

  const points = bonus.points;
  const waitMinutes = Math.ceil(Math.max(0, bonus.buyIn - (now - syncedAt) / 1000) / 60);
  const nextStash = settings.stashLevels[bonus.stashLevel];
  const currentStash = settings.stashLevels[bonus.stashLevel - 1];
  const nextArmory = settings.armoryLevels[bonus.armoryLevel];
  const log = Array.isArray(bonus.log) ? bonus.log : [];
  const earn = settings.earn;
  const stock = new Map(entriesOf(crew.stash));

  const describe = (entry: CrewBonusEntry) => {
    if (entry.kind === 'weapon') return t('{name} achète {item}', { name: entry.name, item: itemLabel(state.config, entry.item ?? '') });
    if (entry.kind === 'stash') return t('{name} agrandit le coffre (niveau {level})', { name: entry.name, level: entry.level ?? 0 });
    return t('{name} améliore l\'armurerie (niveau {level})', { name: entry.name, level: entry.level ?? 0 });
  };

  let armoryInfo = t('Niveau maximum');
  if (nextArmory && bonus.armoryLevel === 0) armoryInfo = t('Ouvrir : armes standard · {cost} pts', { cost: formatNumber(nextArmory.cost) });
  else if (nextArmory) armoryInfo = t('Niveau {level} : armes avancées · {cost} pts', { level: bonus.armoryLevel + 1, cost: formatNumber(nextArmory.cost) });

  return (
    <Panel className="group-panel">
      <div className="crew-bonus__head">
        <span className="label">{t('Points de crew')}</span>
        <span className="disp crew-bonus__points">{t('{points} pts', { points: formatNumber(points) })}</span>
      </div>
      <p className="muted crew-bonus__earn">
        {t('Kill : +{kill} · Territoire pris : +{capture} · Territoire tenu : +{territory} par versement · Guerre gagnée : +{war} · Tournoi gagné : +{tournament}', {
          kill: earn.kill,
          capture: earn.capture,
          territory: earn.territory,
          war: earn.warWin,
          tournament: earn.tournamentWin,
        })}
      </p>

      <ul className="crew-bonus__list">
        <BonusRow
          name={t('Coffre du crew')}
          state={`${t('Niveau {level}/{max}', { level: bonus.stashLevel, max: settings.stashLevels.length })}${currentStash ? ` · +${currentStash.bonus} %` : ''}`}
          info={
            nextStash
              ? t('Niveau {level} : +{bonus} % · {cost} pts', { level: bonus.stashLevel + 1, bonus: nextStash.bonus, cost: formatNumber(nextStash.cost) })
              : t('Niveau maximum')
          }
          action={nextStash && buyButton(points < nextStash.cost, () => crewApi.upgrade('stash'), true)}
        />
        <BonusRow
          name={t('Armurerie du crew')}
          state={bonus.armoryLevel === 0 ? t('Fermée') : t('Niveau {level}/{max}', { level: bonus.armoryLevel, max: settings.armoryLevels.length })}
          info={armoryInfo}
          action={nextArmory && buyButton(points < nextArmory.cost, () => crewApi.upgrade('armory'), true)}
        />
      </ul>

      <span className="label">{t('Armurerie')}</span>
      <ul className="crew-bonus__list">
        {settings.weapons.map((weapon) => {
          const locked = bonus.armoryLevel < weapon.tier;
          const count = stock.get(weapon.item) ?? 0;
          return (
            <BonusRow
              key={weapon.item}
              name={itemLabel(state.config, weapon.item)}
              state={<span className="chip">{weapon.tier >= 2 ? t('Avancée') : t('Standard')}</span>}
              info={t('{stock}/{limit} au coffre · {cost} pts', { stock: count, limit: settings.stockLimit, cost: formatNumber(weapon.cost) })}
              locked={locked}
              action={buyButton(
                locked || count >= settings.stockLimit || waitMinutes > 0 || points < weapon.cost,
                () => crewApi.armoryBuy(weapon.item),
              )}
            />
          );
        })}
      </ul>
      <p className="muted">
        {waitMinutes > 0
          ? t('Prochain achat d\'arme dans {minutes} min.', { minutes: waitMinutes })
          : t('Les armes achetées arrivent dans le coffre du crew, chez le banquier. Un achat toutes les {minutes} min, {limit} exemplaires d\'une arme au plus au coffre.', {
              minutes: Math.round(settings.buyCooldown / 60),
              limit: settings.stockLimit,
            })}
      </p>

      <div className="crew-stash-log">
        <span className="label">{t('Dépenses du crew')}</span>
        {log.length === 0 && <p className="muted crew-stash-log__empty">{t('Aucune dépense pour l\'instant.')}</p>}
        <ul className="crew-stash-log__list">
          {log.map((entry, index) => (
            <li key={`${entry.at}-${index}`} className="crew-stash-log__row">
              <span className="mono crew-stash-log__date">{formatLogDate(entry.at)}</span>
              <span className="crew-stash-log__text">
                {describe(entry)} · {t('-{cost} pts', { cost: formatNumber(entry.cost) })}
              </span>
            </li>
          ))}
        </ul>
      </div>
    </Panel>
  );
}
