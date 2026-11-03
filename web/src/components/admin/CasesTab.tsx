import { useCallback, useEffect, useMemo, useState, type CSSProperties } from 'react';
import { adminApi } from '../../api/adminApi';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CaseAdminCase, CaseAdminData, CaseDefinitionDraft } from '../../types/admin';
import { formatChance, rarityOf } from '../../utils/cases';

/** Groupes de la liste des objets */
const TYPE_LABELS: Record<string, string> = {
  money: 'Argent',
  weapon: 'Armes',
  ammo: 'Munitions',
  consumable: 'Soins et équipement',
  material: 'Matériaux',
  vehicle: 'Véhicules',
  case: 'Caisses',
};

/** Sélection d'une caisse à créer */
const NEW = '';

const toDraft = (definition: CaseAdminCase): CaseDefinitionDraft => ({
  id: definition.id,
  label: definition.label,
  description: definition.description ?? '',
  price: definition.price ?? 0,
  points: definition.points ?? 0,
  level: definition.level ?? 1,
  rewards: definition.rewards.map((reward) => ({
    item: reward.item,
    count: Array.isArray(reward.count) ? [reward.count[0], reward.count[1]] : [reward.count ?? 1, reward.count ?? 1],
    weight: reward.weight,
    rarity: reward.rarity,
  })),
});

const emptyDraft = (): CaseDefinitionDraft => ({
  label: '',
  description: '',
  price: 0,
  points: 0,
  level: 1,
  rewards: [{ item: 'money', count: [500, 1500], weight: 100, rarity: 'common' }],
});

const toNumber = (value: string) => (value === '' ? 0 : Number(value));

/** Caisses : création, nom, prix, niveau, récompenses et chances, retrait de la page. Enregistrées en base. */
export function CasesTab() {
  useT();
  const { state, actions } = useGame();
  const { config } = state;
  const [data, setData] = useState<CaseAdminData | null>(null);
  const [selected, setSelected] = useState<string>(NEW);
  const [draft, setDraft] = useState<CaseDefinitionDraft>(emptyDraft);
  const [confirmReset, setConfirmReset] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async (keep?: string) => {
    const result = await adminApi.cases();
    if (!result?.ok) return actions.notify(result?.message ?? t('Caisses indisponibles.'), 'error');
    setData(result);
    const next = result.cases.find((entry) => entry.id === keep) ?? (keep === NEW ? undefined : result.cases[0]);
    setSelected(next?.id ?? NEW);
    setDraft(next ? toDraft(next) : emptyDraft());
  }, [actions]);

  useEffect(() => {
    load();
  }, [load]);

  const current = data?.cases.find((entry) => entry.id === selected) ?? null;
  const dirty = useMemo(
    () => JSON.stringify(current ? toDraft(current) : emptyDraft()) !== JSON.stringify(draft),
    [current, draft],
  );

  const itemGroups = useMemo(() => {
    const groups: Record<string, CaseAdminData['items']> = {};
    for (const item of data?.items ?? []) (groups[item.type] ??= []).push(item);
    return Object.entries(groups).sort(([a], [b]) => (a === 'money' ? -1 : b === 'money' ? 1 : 0));
  }, [data]);

  const rarities = useMemo(
    () => Object.entries(config.caseRarities ?? {}).sort(([, a], [, b]) => a.order - b.order),
    [config.caseRarities],
  );

  if (!data) return <p className="muted">{t('Chargement des caisses…')}</p>;

  const limits = data.limits;
  const total = draft.rewards.reduce((sum, reward) => sum + (reward.weight > 0 ? reward.weight : 0), 0);
  const incomplete = draft.label.trim() === '' || draft.rewards.length === 0 || draft.rewards.some((reward) => !(reward.weight > 0));
  const full = !current && data.cases.length >= limits.maxCases;

  const select = (id: string) => {
    const next = data.cases.find((entry) => entry.id === id);
    setSelected(next?.id ?? NEW);
    setDraft(next ? toDraft(next) : emptyDraft());
    setConfirmReset(false);
  };
  const patch = (fields: Partial<CaseDefinitionDraft>) => setDraft({ ...draft, ...fields });
  const clamp = (value: string, max: number) => Math.min(max, Math.max(0, Math.floor(toNumber(value))));
  const updateReward = (index: number, fields: Partial<CaseDefinitionDraft['rewards'][number]>) =>
    patch({ rewards: draft.rewards.map((reward, i) => (i === index ? { ...reward, ...fields } : reward)) });
  const countMax = (item: string) => (item === 'money' ? limits.maxMoney : limits.maxCount);

  const report = (result: { ok: boolean; message?: string } | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    return Boolean(result?.ok);
  };
  const save = async () => {
    setBusy(true);
    const result = await adminApi.caseSave({ ...draft, id: current?.id });
    if (report(result)) await load(result?.id);
    setBusy(false);
  };
  const toggleRemoved = async () => {
    if (!current) return;
    setBusy(true);
    if (report(await adminApi.caseRemove(current.id, !current.removed))) await load(current.id);
    setBusy(false);
  };
  const reset = async () => {
    if (!current) return;
    if (!confirmReset) return setConfirmReset(true);
    setConfirmReset(false);
    setBusy(true);
    if (report(await adminApi.caseReset(current.id))) await load(current.id);
    setBusy(false);
  };

  return (
    <div className="admin-loot">
      <nav className="admin-loot__tables admin-cases__list">
        {data.cases.map((entry) => (
          <button
            key={entry.id}
            className={entry.id === selected ? 'admin-loot__table admin-loot__table--active' : 'admin-loot__table'}
            onClick={() => select(entry.id)}
          >
            <span className="disp">{t(entry.label)}</span>
            {entry.removed ? (
              <span className="mono admin-cases__removed">{t('RETIRÉE')}</span>
            ) : entry.custom ? (
              <span className="mono admin-loot__modified">{t('CRÉÉE')}</span>
            ) : (
              entry.modified && <span className="mono admin-loot__modified">{t('MODIFIÉE')}</span>
            )}
          </button>
        ))}
        <button
          className={selected === NEW ? 'admin-loot__table admin-loot__table--active' : 'admin-loot__table'}
          disabled={data.cases.length >= limits.maxCases}
          onClick={() => select(NEW)}
        >
          <span className="disp">{t('+ Nouvelle caisse')}</span>
        </button>
      </nav>

      <p className="muted admin-loot__used">
        {current?.removed
          ? t('Retirée de la page : plus vendue ni ouverte en points. Celles déjà possédées s\'ouvrent encore.')
          : t('Appliqué tout de suite à tous les joueurs. Prix ou points à 0 : pas en vente de cette façon. La chance d\'une récompense est son poids divisé par le total des poids.')}
      </p>

      <div className="admin-cases__fields">
        <label className="admin-cases__field admin-cases__field--wide">
          <span className="label">{t('Nom')}</span>
          <input
            className="admin-input"
            value={draft.label}
            maxLength={40}
            placeholder={t('Caisse de…')}
            onChange={(event) => patch({ label: event.target.value })}
          />
        </label>
        <label className="admin-cases__field admin-cases__field--wide">
          <span className="label">{t('Description')}</span>
          <input
            className="admin-input"
            value={draft.description}
            maxLength={160}
            onChange={(event) => patch({ description: event.target.value })}
          />
        </label>
        <label className="admin-cases__field">
          <span className="label">{t('Prix $')}</span>
          <input
            className="admin-input"
            type="number"
            min={0}
            max={limits.maxPrice}
            value={draft.price}
            onChange={(event) => patch({ price: clamp(event.target.value, limits.maxPrice) })}
          />
        </label>
        <label className="admin-cases__field">
          <span className="label">{t('Points boutique')}</span>
          <input
            className="admin-input"
            type="number"
            min={0}
            max={limits.maxPoints}
            value={draft.points}
            onChange={(event) => patch({ points: clamp(event.target.value, limits.maxPoints) })}
          />
        </label>
        <label className="admin-cases__field">
          <span className="label">{t('Niveau requis')}</span>
          <input
            className="admin-input"
            type="number"
            min={1}
            max={limits.maxLevel}
            value={draft.level}
            onChange={(event) => patch({ level: Math.max(1, clamp(event.target.value, limits.maxLevel)) })}
          />
        </label>
      </div>

      <div className="admin-cases__head mono">
        <span>{t('RÉCOMPENSE')}</span>
        <span>{t('QTÉ MIN')}</span>
        <span>{t('QTÉ MAX')}</span>
        <span>{t('POIDS')}</span>
        <span>{t('RARETÉ')}</span>
        <span>{t('CHANCE')}</span>
        <span />
      </div>
      <ul className="admin-loot__rows">
        {draft.rewards.map((reward, index) => (
          <li
            key={index}
            className="admin-cases__row"
            style={{ '--rarity': rarityOf(config, reward.rarity).color } as CSSProperties}
          >
            <select
              className="admin-input"
              value={reward.item}
              aria-label={t('Objet')}
              onChange={(event) => updateReward(index, { item: event.target.value })}
            >
              {itemGroups.map(([type, items]) => (
                <optgroup key={type} label={t(TYPE_LABELS[type] ?? type)}>
                  {items.map((item) => (
                    <option key={item.name} value={item.name}>{t(item.label)}</option>
                  ))}
                </optgroup>
              ))}
            </select>
            <input
              className="admin-input"
              type="number"
              min={1}
              max={countMax(reward.item)}
              value={reward.count[0]}
              aria-label={t('Quantité minimum')}
              onChange={(event) => updateReward(index, { count: [clamp(event.target.value, countMax(reward.item)), reward.count[1]] })}
            />
            <input
              className="admin-input"
              type="number"
              min={1}
              max={countMax(reward.item)}
              value={reward.count[1]}
              aria-label={t('Quantité maximum')}
              onChange={(event) => updateReward(index, { count: [reward.count[0], clamp(event.target.value, countMax(reward.item))] })}
            />
            <input
              className="admin-input"
              type="number"
              min={0.01}
              step={0.01}
              value={reward.weight}
              aria-label={t('Poids du tirage')}
              onChange={(event) => updateReward(index, { weight: Math.max(0, toNumber(event.target.value)) })}
            />
            <select
              className="admin-input admin-cases__rarity"
              value={reward.rarity}
              aria-label={t('Rareté')}
              onChange={(event) => updateReward(index, { rarity: event.target.value })}
            >
              {rarities.map(([id, rarity]) => (
                <option key={id} value={id}>{t(rarity.label)}</option>
              ))}
            </select>
            <span className="mono admin-cases__chance">
              {total > 0 && reward.weight > 0 ? formatChance((reward.weight / total) * 100) : '—'}
            </span>
            <button
              className="btn btn--small btn--danger"
              aria-label={t('Retirer la ligne')}
              onClick={() => patch({ rewards: draft.rewards.filter((_, i) => i !== index) })}
            >
              ✕
            </button>
          </li>
        ))}
      </ul>
      <button
        className="btn btn--small"
        disabled={draft.rewards.length >= limits.maxRewards}
        onClick={() =>
          patch({ rewards: [...draft.rewards, { item: data.items[0]?.name ?? 'money', count: [1, 1], weight: 10, rarity: rarities[0]?.[0] ?? 'common' }] })
        }
      >
        {t('+ Ajouter une récompense')}
      </button>

      <div className="admin-loot__actions">
        <button className="btn btn--small btn--primary" disabled={!dirty || incomplete || full || busy} onClick={save}>
          {current ? t('Enregistrer') : t('Créer la caisse')}
        </button>
        <button className="btn btn--small" disabled={!dirty || busy} onClick={() => select(selected)}>
          {t('Annuler')}
        </button>
        {current && (
          <button className="btn btn--small" disabled={busy} onClick={toggleRemoved}>
            {current.removed ? t('Remettre sur la page') : t('Retirer de la page')}
          </button>
        )}
        {current && !current.custom && (
          <button className="btn btn--small btn--danger" disabled={busy} onClick={reset}>
            {confirmReset ? t('Confirmer : valeurs par défaut') : t('Valeurs par défaut')}
          </button>
        )}
      </div>
    </div>
  );
}
