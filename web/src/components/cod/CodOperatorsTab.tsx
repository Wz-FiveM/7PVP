import { useEffect, useState } from 'react';
import { codApi } from '../../api/codApi';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CodActionResult, CodCatalog, CodOperatorEntry, CodProfile } from '../../types/cod';
import { formatPoints } from '../../utils/format';
import { BracketButton } from './CodParts';

/** Le personnage du joueur, dans la liste et pour l'aperçu */
const OWN = 'own';

interface CodOperatorsTabProps {
  profile: CodProfile;
  catalog: CodCatalog;
  onProfile: (profile: CodProfile) => void;
}

/** Personnages : liste à gauche, aperçu sur le personnage du menu au centre, accès et achat à droite. */
export function CodOperatorsTab({ profile, catalog, onProfile }: CodOperatorsTabProps) {
  useT();
  const { state, actions } = useGame();
  const worn = profile.operator || OWN;
  const [selectedId, setSelectedId] = useState(worn);
  const [busy, setBusy] = useState(false);
  const selected = catalog.operators.find((entry) => entry.id === selectedId);
  const points = state.config.shopPoints;
  const pointsShort = points?.short ? t(points.short) : undefined;
  const balance = state.player?.shopPoints ?? 0;
  const vip = profile.vipDays > 0;

  useEffect(() => () => void codApi.previewOperator(null), []);

  const choose = (id: string) => {
    setSelectedId(id);
    void codApi.previewOperator(id);
  };
  const run = async (action: Promise<CodActionResult>) => {
    setBusy(true);
    const result = await action;
    setBusy(false);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    if (result?.profile) onProfile(result.profile);
  };

  /** Ce qu'affiche la ligne d'un personnage, à droite de son nom */
  const rowMeta = (entry: CodOperatorEntry) => {
    if (entry.id === worn) return t('PORTÉ');
    if (!entry.available) return t('BIENTÔT');
    if (profile.ownedOperators.includes(entry.id)) return t('ACQUIS');
    return vip ? t('VIP') : formatPoints(entry.price, pointsShort);
  };

  return (
    <>
      <section className="cod-column">
        <span className="cod-label">{t('Personnages')}</span>
        <ul className="cod-list cod-list--scroll">
          <li>
            <button
              className={selectedId === OWN ? 'cod-list__row cod-list__row--active' : 'cod-list__row'}
              onClick={() => choose(OWN)}
            >
              <span className="cod-list__stack">
                <span>{t('Mon personnage')}</span>
                <span className="cod-list__hint">{t('Celui que tu as créé')}</span>
              </span>
              <span className="cod-list__meta">{worn === OWN ? t('PORTÉ') : ''}</span>
            </button>
          </li>
          {catalog.operators.map((entry) => (
            <li key={entry.id}>
              <button
                className={[
                  'cod-list__row',
                  entry.id === selectedId && 'cod-list__row--active',
                  !entry.available && 'cod-list__row--locked',
                ].filter(Boolean).join(' ')}
                onClick={() => choose(entry.id)}
              >
                <span className="cod-list__stack">
                  <span>{entry.label}</span>
                  <span className="cod-list__hint">{entry.universe}</span>
                </span>
                <span className="cod-list__meta">{rowMeta(entry)}</span>
              </button>
            </li>
          ))}
        </ul>
      </section>

      <section className="cod-column cod-column--right">
        <div className="cod-operators__access">
          <span className="cod-label">{vip ? t('VIP actif') : t('Sans VIP')}</span>
          <p className="cod-text">
            {vip
              ? t('Tous les personnages te sont ouverts pendant encore {count} jour(s).', { count: profile.vipDays })
              : t('Le VIP ouvre tous les personnages tant qu\'il dure.')}
          </p>
          <span className="cod-operators__balance">
            {formatPoints(balance, pointsShort)}
            {points?.storeUrl && <button className="cod-leave" onClick={actions.openStore}>{t('Boutique')}</button>}
          </span>
        </div>

        {selected
          ? <OperatorDetails
              key={selected.id}
              operator={selected}
              profile={profile}
              worn={selected.id === worn}
              vip={vip}
              balance={balance}
              pointsShort={pointsShort}
              busy={busy}
              onSelect={() => run(codApi.selectOperator(selected.id, profile))}
              onBuy={() => run(codApi.buyOperator(selected.id, profile))}
            />
          : (
            <>
              <h2 className="cod-operators__name">{t('Mon personnage')}</h2>
              <p className="cod-text">{t('Celui que tu as créé, avec ton apparence.')}</p>
              <div className="cod-column__foot">
                <BracketButton onClick={() => run(codApi.selectOperator(null, profile))} disabled={busy || worn === OWN}>
                  {worn === OWN ? t('Porté') : t('Porter ce personnage')}
                </BracketButton>
              </div>
            </>
          )}
      </section>
    </>
  );
}

interface OperatorDetailsProps {
  operator: CodOperatorEntry;
  profile: CodProfile;
  worn: boolean;
  vip: boolean;
  balance: number;
  pointsShort?: string;
  busy: boolean;
  onSelect: () => void;
  onBuy: () => void;
}

function OperatorDetails({ operator, profile, worn, vip, balance, pointsShort, busy, onSelect, onBuy }: OperatorDetailsProps) {
  useT();
  const owned = profile.ownedOperators.includes(operator.id);
  const price = formatPoints(operator.price, pointsShort);
  const missing = operator.price - balance;

  const status = () => {
    if (!operator.available) return t('Ce personnage n\'est pas encore installé sur le serveur.');
    if (owned) return t('Acheté : il reste à toi pour toujours.');
    if (vip) return t('Inclus avec ton VIP.');
    return t('Réservé aux VIP, ou à toi pour toujours avec des points boutique.');
  };

  return (
    <>
      <h2 className="cod-operators__name">{operator.label}</h2>
      <span className="cod-list__hint">{operator.universe} · {t('Modèle : {author}', { author: operator.credit })}</span>
      <p className="cod-text">{status()}</p>
      {operator.available && (
        <div className="cod-column__foot">
          {!owned && missing > 0 && (
            <p className="cod-text">{t('Il te manque {count}.', { count: formatPoints(missing, pointsShort) })}</p>
          )}
          {(owned || vip) && (
            <BracketButton onClick={onSelect} disabled={busy || worn}>
              {worn ? t('Porté') : t('Porter ce personnage')}
            </BracketButton>
          )}
          {!owned && (
            <BracketButton onClick={onBuy} disabled={busy || missing > 0}>
              {vip ? t('Garder pour toujours · {price}', { price }) : t('Acheter · {price}', { price })}
            </BracketButton>
          )}
        </div>
      )}
    </>
  );
}
