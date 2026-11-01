import { useCallback, useEffect, useMemo, useState } from 'react';
import { adminApi } from '../../api/adminApi';
import { t, useLanguage, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { ResaleAdminData, ResaleAdminItem } from '../../types/admin';
import { formatMoney } from '../../utils/format';

/** Groupes de la liste, dans l'ordre */
const SECTIONS: { type: string; label: string }[] = [
  { type: 'weapon', label: 'Armes' },
  { type: 'ammo', label: 'Munitions' },
  { type: 'attachment', label: 'Accessoires' },
  { type: 'consumable', label: 'Soins et équipement' },
  { type: 'vehicle', label: 'Véhicules' },
  { type: 'case', label: 'Caisses' },
  { type: 'material', label: 'Matériaux' },
];

type Draft = Record<string, number>;

const toDraft = (items: ResaleAdminItem[]): Draft => Object.fromEntries(items.map((item) => [item.name, item.price]));

/** Prix du receleur, par unité : enregistrés en base, 0 = objet pas repris. */
export function ResaleTab() {
  useT();
  const language = useLanguage();
  const { actions } = useGame();
  const [data, setData] = useState<ResaleAdminData | null>(null);
  const [draft, setDraft] = useState<Draft>({});
  const [search, setSearch] = useState('');
  const [confirmReset, setConfirmReset] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const result = await adminApi.resale();
    if (!result?.ok) return actions.notify(result?.message ?? t('Prix de revente indisponibles.'), 'error');
    setData(result);
    setDraft(toDraft(result.items));
  }, [actions]);

  useEffect(() => {
    load();
  }, [load]);

  const changed = useMemo(() => {
    const prices: Draft = {};
    for (const item of data?.items ?? []) {
      if (draft[item.name] !== item.price) prices[item.name] = draft[item.name];
    }
    return prices;
  }, [data, draft]);
  const changedCount = Object.keys(changed).length;

  const visible = useMemo(() => {
    const query = search.trim().toLowerCase();
    return (data?.items ?? []).filter((item) => !query || t(item.label).toLowerCase().includes(query));
  }, [data, search, language]);

  if (!data) return <p className="muted">{t('Chargement des prix…')}</p>;

  const maxPrice = data.maxPrice;
  const setPrice = (name: string, value: string) =>
    setDraft({ ...draft, [name]: Math.min(maxPrice, Math.max(0, Math.floor(Number(value) || 0))) });
  /** Multiplie les prix des objets affichés (ceux de la recherche) */
  const scale = (factor: number) => {
    const next = { ...draft };
    for (const item of visible) next[item.name] = Math.min(maxPrice, Math.round(next[item.name] * factor));
    setDraft(next);
  };

  const report = (result: { ok: boolean; message?: string } | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    return Boolean(result?.ok);
  };
  const save = async () => {
    setBusy(true);
    if (report(await adminApi.resaleSave(changed))) await load();
    setBusy(false);
  };
  const reset = async () => {
    if (!confirmReset) return setConfirmReset(true);
    setConfirmReset(false);
    setBusy(true);
    if (report(await adminApi.resaleReset())) await load();
    setBusy(false);
  };

  return (
    <div className="admin-loot">
      <p className="muted admin-loot__used">
        {t('Prix par unité payé par le receleur, 0 : objet pas repris. Un prix égal ou supérieur à celui de la boutique permet de gagner de l\'argent sans limite en achetant puis revendant.')}
      </p>
      <div className="admin-loot__money">
        <input
          className="admin-input"
          value={search}
          placeholder={t('Nom d\'un objet…')}
          aria-label={t('Rechercher')}
          onChange={(event) => setSearch(event.target.value)}
        />
        <span className="admin-loot__scale">
          <button className="btn btn--small" onClick={() => scale(0.5)}>{t('Prix affichés ×0,5')}</button>
          <button className="btn btn--small" onClick={() => scale(2)}>×2</button>
        </span>
      </div>

      <div className="admin-resale__head mono">
        <span>{t('OBJET')}</span>
        <span>{t('BOUTIQUE')}</span>
        <span>{t('DÉFAUT')}</span>
        <span>{t('PRIX $')}</span>
      </div>
      {SECTIONS.map((section) => {
        const list = visible.filter((item) => item.type === section.type);
        if (list.length === 0) return null;
        return (
          <section key={section.type} className="admin-resale__section">
            <span className="label">{t(section.label)}</span>
            <ul className="admin-loot__rows">
              {list.map((item) => {
                const price = draft[item.name];
                const risky = item.shop !== false && price >= item.shop;
                return (
                  <li key={item.name} className={risky ? 'admin-resale__row admin-resale__row--risky' : 'admin-resale__row'}>
                    <span className="admin-resale__name">
                      {t(item.label)}
                      {price !== item.price && <span className="mono admin-loot__modified"> {t('MODIFIÉ')}</span>}
                    </span>
                    <span className="mono muted">
                      {item.shop === false ? '—' : Number.isInteger(item.shop) ? formatMoney(item.shop) : `$${item.shop.toFixed(2)}`}
                    </span>
                    <span className="mono muted">{formatMoney(item.default)}</span>
                    <input
                      className="admin-input"
                      type="number"
                      min={0}
                      max={maxPrice}
                      value={price}
                      aria-label={t('Prix de revente de {item}', { item: t(item.label) })}
                      onChange={(event) => setPrice(item.name, event.target.value)}
                    />
                  </li>
                );
              })}
            </ul>
          </section>
        );
      })}

      <div className="admin-loot__actions admin-resale__actions">
        <button className="btn btn--small btn--primary" disabled={changedCount === 0 || busy} onClick={save}>
          {changedCount > 0 ? t('Enregistrer ({count})', { count: changedCount }) : t('Enregistrer')}
        </button>
        <button className="btn btn--small" disabled={changedCount === 0 || busy} onClick={() => setDraft(toDraft(data.items))}>
          {t('Annuler')}
        </button>
        <button className="btn btn--small btn--danger" disabled={busy} onClick={reset}>
          {confirmReset ? t('Confirmer : valeurs par défaut') : t('Valeurs par défaut')}
        </button>
      </div>
    </div>
  );
}
