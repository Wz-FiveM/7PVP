import { useCallback, useEffect, useMemo, useState } from 'react';
import { adminApi } from '../../api/adminApi';
import { t, useLanguage, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { WeightAdminData, WeightAdminItem } from '../../types/admin';

/** Filtres de la liste, dans l'ordre affiché */
const FILTERS: { type: string; label: string }[] = [
  { type: 'all', label: 'Tout' },
  { type: 'weapon', label: 'Armes' },
  { type: 'ammo', label: 'Munitions' },
  { type: 'consumable', label: 'Soins & équipement' },
  { type: 'vehicle', label: 'Véhicules' },
  { type: 'material', label: 'Matériaux' },
  { type: 'other', label: 'Autres' },
];
const LISTED = new Set(FILTERS.map((filter) => filter.type));

type Draft = Record<string, number>;

const toDraft = (items: WeightAdminItem[]): Draft => Object.fromEntries(items.map((item) => [item.name, item.weight]));
/** Au gramme près, comme le serveur */
const round = (value: number) => Math.round(value * 1000) / 1000;
const matches = (item: WeightAdminItem, type: string) =>
  type === 'all' || item.type === type || (type === 'other' && !LISTED.has(item.type));

/** Poids de chaque objet, en kg par unité : enregistrés en base, appliqués tout de suite aux sacs et coffres. */
export function WeightsTab() {
  useT();
  const language = useLanguage();
  const { actions } = useGame();
  const [data, setData] = useState<WeightAdminData | null>(null);
  const [draft, setDraft] = useState<Draft>({});
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all');
  const [bulk, setBulk] = useState('1');
  const [confirmReset, setConfirmReset] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const result = await adminApi.weights();
    if (!result?.ok) return actions.notify(result?.message ?? t('Poids des objets indisponibles.'), 'error');
    setData(result);
    setDraft(toDraft(result.items));
  }, [actions]);

  useEffect(() => {
    load();
  }, [load]);

  const changed = useMemo(() => {
    const weights: Draft = {};
    for (const item of data?.items ?? []) {
      if (draft[item.name] !== item.weight) weights[item.name] = draft[item.name];
    }
    return weights;
  }, [data, draft]);
  const changedCount = Object.keys(changed).length;

  const visible = useMemo(() => {
    const query = search.trim().toLowerCase();
    return (data?.items ?? [])
      .filter((item) => matches(item, filter) && (!query || t(item.label).toLowerCase().includes(query)))
      .sort((a, b) => t(a.label).localeCompare(t(b.label), language));
  }, [data, search, filter, language]);

  if (!data) return <p className="muted">{t('Chargement des poids…')}</p>;

  const clamp = (value: number) => round(Math.min(data.maxWeight, Math.max(0, value || 0)));
  const setWeight = (name: string, value: string) => setDraft({ ...draft, [name]: clamp(Number(value)) });
  /** Même poids pour tous les objets affichés (filtre et recherche) */
  const applyBulk = () => {
    const weight = clamp(Number(bulk.replace(',', '.')));
    const next = { ...draft };
    for (const item of visible) next[item.name] = weight;
    setDraft(next);
  };

  const report = (result: { ok: boolean; message?: string } | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    return Boolean(result?.ok);
  };
  const save = async () => {
    setBusy(true);
    if (report(await adminApi.weightsSave(changed))) await load();
    setBusy(false);
  };
  const reset = async () => {
    if (!confirmReset) return setConfirmReset(true);
    setConfirmReset(false);
    setBusy(true);
    if (report(await adminApi.weightsReset())) await load();
    setBusy(false);
  };

  return (
    <div className="admin-weights">
      <p className="muted">
        {t('Poids d\'une unité, appliqué tout de suite à tous les joueurs. Un sac devenu trop lourd garde ses objets : il ne peut seulement plus rien recevoir.')}
      </p>
      <input
        className="admin-input"
        value={search}
        placeholder={t('Nom d\'un objet…')}
        aria-label={t('Rechercher')}
        onChange={(event) => setSearch(event.target.value)}
      />
      <div className="admin-chips">
        {FILTERS.map((entry) => (
          <button
            key={entry.type}
            className={entry.type === filter ? 'admin-chip admin-chip--active' : 'admin-chip'}
            onClick={() => setFilter(entry.type)}
          >
            {t(entry.label)}
          </button>
        ))}
      </div>
      <div className="admin-weights__bulk">
        <span className="muted">{t('Tous les objets affichés ({count}) à', { count: visible.length })}</span>
        <input
          className="admin-input admin-input--small"
          inputMode="decimal"
          value={bulk}
          aria-label={t('Poids pour tous les objets affichés')}
          onChange={(event) => setBulk(event.target.value)}
        />
        <span className="muted">kg</span>
        <button className="btn btn--small" disabled={visible.length === 0} onClick={applyBulk}>
          {t('Appliquer')}
        </button>
      </div>

      <div className="admin-weights__head mono">
        <span>{t('OBJET')}</span>
        <span>{t('DÉFAUT')}</span>
        <span>{t('POIDS KG')}</span>
      </div>
      <ul className="admin-weights__rows">
        {visible.map((item) => {
          const weight = draft[item.name];
          return (
            <li key={item.name} className={weight !== item.weight ? 'admin-weights__row admin-weights__row--edited' : 'admin-weights__row'}>
              <span className="admin-weights__name">
                {t(item.label)}
                {weight !== item.weight && <span className="mono admin-loot__modified"> {t('MODIFIÉ')}</span>}
                {weight === item.weight && item.weight !== item.default && <span className="mono muted"> {t('PERSO')}</span>}
              </span>
              <span className="mono muted">{item.default}</span>
              <input
                className="admin-input"
                type="number"
                min={0}
                max={data.maxWeight}
                step={0.01}
                value={weight}
                aria-label={t('Poids de {item}', { item: t(item.label) })}
                onChange={(event) => setWeight(item.name, event.target.value)}
              />
            </li>
          );
        })}
        {visible.length === 0 && <li className="muted">{t('Aucun objet ne correspond.')}</li>}
      </ul>

      <div className="admin-loot__actions admin-weights__actions">
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
