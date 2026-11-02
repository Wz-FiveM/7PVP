import { useEffect, useState, type FormEvent } from 'react';
import { bountyApi, type BountyTarget } from '../api/bountyApi';
import { Panel } from '../components/ui/Panel';
import { useT } from '../i18n';
import { useGame } from '../store/GameContext';
import { formatMoney } from '../utils/format';
import './pages.css';

/** Primes : les têtes mises à prix, et poser la sienne sur un joueur en PvP. */
export function BountiesPage() {
  const t = useT();
  const { state, actions } = useGame();
  const settings = state.config.bountyPlayer;
  const [targets, setTargets] = useState<BountyTarget[]>([]);
  const [target, setTarget] = useState('');
  const [amount, setAmount] = useState('');

  useEffect(() => {
    let cancelled = false;
    bountyApi.targets().then((result) => {
      if (!cancelled) setTargets(Array.isArray(result?.list) ? result.list : []);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  if (!settings) return null;
  const value = Number(amount);
  const cost = value + Math.ceil(value * settings.fee);

  const submit = (event: FormEvent) => {
    event.preventDefault();
    bountyApi.place(Number(target), value).then((result) => {
      if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
      if (result?.ok) setAmount('');
    });
  };

  return (
    <div className="bounty-page">
      <Panel className="group-panel">
        <span className="label">{t('Poser une prime')}</span>
        <form className="bounty-form" onSubmit={submit}>
          <select className="field" value={target} onChange={(event) => setTarget(event.target.value)}>
            <option value="">{t('Choisis un joueur')}</option>
            {targets.map((entry) => (
              <option key={entry.id} value={entry.id}>
                {entry.name} (ID {entry.id})
              </option>
            ))}
          </select>
          <input
            className="field"
            value={amount}
            onChange={(event) => setAmount(event.target.value.replace(/\D/g, ''))}
            placeholder={t('Montant')}
            inputMode="numeric"
          />
          <button className="btn btn--primary btn--small cut-s" disabled={!target || value < settings.min || value > settings.max}>
            {value > 0 ? t('Payer {price}', { price: formatMoney(cost) }) : t('Payer')}
          </button>
        </form>
        <p className="muted">
          {t('De {min} à {max}, plus des frais perdus de {fee} %. La prime reste sur sa tête jusqu\'à sa mort, même s\'il se déconnecte.', {
            min: formatMoney(settings.min),
            max: formatMoney(settings.max),
            fee: Math.round(settings.fee * 100),
          })}
        </p>
      </Panel>

      <Panel className="group-panel">
        <span className="label">{t('Têtes mises à prix')}</span>
        {state.bounties.length === 0 ? (
          <p className="muted">{t('Aucune prime en cours.')}</p>
        ) : (
          <ul className="bounty-list">
            {state.bounties.map((entry) => (
              <li key={entry.id} className="bounty-list__row">
                <span>{entry.name}</span>
                <span className="mono">{formatMoney(entry.amount)}</span>
              </li>
            ))}
          </ul>
        )}
      </Panel>
    </div>
  );
}
