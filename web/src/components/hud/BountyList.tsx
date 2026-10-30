import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { formatMoney } from '../../utils/format';

/** Têtes mises à prix (hors la sienne), sous le killfeed. */
export function BountyList() {
  const t = useT();
  const { state } = useGame();
  const others = state.bounties.filter((entry) => entry.id !== state.player?.source);
  if (others.length === 0) return null;

  return (
    <div className="bounties">
      <span className="label bounties__title">{t('Primes')}</span>
      {others.map((entry) => (
        <div key={entry.id} className="bounties__item cut-s">
          <span className="bounties__name">{entry.name}</span>
          <span className="mono bounties__amount">{formatMoney(entry.amount)}</span>
        </div>
      ))}
    </div>
  );
}
