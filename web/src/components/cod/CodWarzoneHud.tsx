import { useState } from 'react';
import { codApi } from '../../api/codApi';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CodObjective, CodWzShopItem, CodWzState } from '../../types/cod';
import { BracketButton, formatTime } from './CodParts';

type WzObjective = Extract<CodObjective, { kind: 'wz' }>;

/** Haut de l'écran : prochaine étape de la zone, joueurs et escouades encore en course. */
export function CodWzZone({ objective }: { objective: WzObjective }) {
  useT();
  const title = objective.state === 'shrink'
    ? t('LA ZONE SE RESSERRE')
    : objective.state === 'final' ? t('DERNIÈRE ZONE') : t('PROCHAINE ZONE');
  return (
    <span className="cod-bomb cod-wz__zone">
      <span className="cod-label">{title}{objective.state !== 'final' && ` · ${formatTime(objective.seconds)}`}</span>
      <span className="cod-bomb__timer">{t('{alive} JOUEURS · {squads} ESCOUADES', { alive: objective.alive, squads: objective.squads })}</span>
    </span>
  );
}

/** Argent et plaques, au-dessus des munitions. */
export function CodWzStatus({ wz, plateKey }: { wz: CodWzState | null; plateKey?: string }) {
  useT();
  if (!wz) return null;
  return (
    <div className="cod-wz__status">
      <span className="cod-wz__cash">${wz.cash.toLocaleString()}</span>
      <span className="cod-wz__plates">
        {plateKey && <span className="cod-key">{plateKey}</span>}
        {t('{count} plaques', { count: wz.plates })}
      </span>
    </div>
  );
}

/** Station d'achat : le serveur vérifie l'argent et la distance à chaque achat. */
export function CodWzShop({ items, cash }: { items: CodWzShopItem[]; cash: number }) {
  useT();
  const { actions } = useGame();
  const [busy, setBusy] = useState(false);

  const buy = async (id: string) => {
    setBusy(true);
    const result = await codApi.wzBuy(id);
    setBusy(false);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };

  return (
    <div className="cod-wz__shop">
      <header className="cod-board__head">
        <span className="cod-board__title">{t('Station d\'achat')}</span>
        <span className="cod-wz__cash">${cash.toLocaleString()}</span>
      </header>
      <ul className="cod-options">
        {items.map((item) => (
          <li key={item.id}>
            <button className="cod-option" disabled={busy || cash < item.price} onClick={() => void buy(item.id)}>
              <span className="cod-option__text">
                <span>{t(item.label)}</span>
                <span className="cod-list__hint">{t(item.description)}</span>
              </span>
              <span className="cod-option__level">${item.price.toLocaleString()}</span>
            </button>
          </li>
        ))}
      </ul>
      <BracketButton onClick={() => void codApi.wzShopClose()}>{t('Fermer')}</BracketButton>
    </div>
  );
}
