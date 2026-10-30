import { useCallback, useEffect, useMemo, useState } from 'react';
import { adminApi } from '../../api/adminApi';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { LootAdminData, LootDrop, LootTableData } from '../../types/admin';

/** Groupes de la liste des objets */
const TYPE_LABELS: Record<string, string> = {
  weapon: 'Armes',
  ammo: 'Munitions',
  consumable: 'Soins et équipement',
  attachment: 'Accessoires',
  material: 'Matériaux',
  vehicle: 'Véhicules',
};

type Draft = Pick<LootTableData, 'money' | 'drops'>;

const copy = (table: LootTableData): Draft => ({
  money: table.money ? [table.money[0], table.money[1]] : false,
  drops: table.drops.map((drop) => ({ ...drop, count: [drop.count[0], drop.count[1]] })),
});

const toNumber = (value: string) => (value === '' ? 0 : Number(value));

/** Butin des zombies et des largages : objets, quantités, chances et argent, enregistrés en base. */
export function LootTab() {
  useT();
  const { actions } = useGame();
  const [data, setData] = useState<LootAdminData | null>(null);
  const [name, setName] = useState<string | null>(null);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [zones, setZones] = useState<Record<string, string>>({});
  const [confirmReset, setConfirmReset] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async (keep?: string | null) => {
    const result = await adminApi.loot();
    if (!result?.ok) return actions.notify(result?.message ?? t('Butin indisponible.'), 'error');
    setData(result);
    setZones(Object.fromEntries(result.zones.map((zone) => [zone.id, zone.loot])));
    const selected = result.tables.find((table) => table.name === keep) ?? result.tables[0];
    setName(selected?.name ?? null);
    setDraft(selected ? copy(selected) : null);
  }, [actions]);

  useEffect(() => {
    load();
  }, [load]);

  const table = data?.tables.find((entry) => entry.name === name) ?? null;
  const dirty = useMemo(() => Boolean(table && draft && JSON.stringify(copy(table)) !== JSON.stringify(draft)), [table, draft]);
  const zonesDirty = data ? data.zones.some((zone) => zones[zone.id] !== zone.loot) : false;

  const itemGroups = useMemo(() => {
    const groups: Record<string, LootAdminData['items']> = {};
    for (const item of data?.items ?? []) (groups[item.type] ??= []).push(item);
    return Object.entries(groups);
  }, [data]);

  if (!data || !table || !draft) return <p className="muted">{t('Chargement du butin…')}</p>;

  const select = (next: LootTableData) => {
    setName(next.name);
    setDraft(copy(next));
    setConfirmReset(false);
  };
  const updateDrop = (index: number, patch: Partial<LootDrop>) =>
    setDraft({ ...draft, drops: draft.drops.map((drop, i) => (i === index ? { ...drop, ...patch } : drop)) });
  const scaleChances = (factor: number) =>
    setDraft({
      ...draft,
      drops: draft.drops.map((drop) => ({ ...drop, chance: Math.min(100, Math.max(0.1, Math.round(drop.chance * factor * 10) / 10)) })),
    });

  const report = (result: { ok: boolean; message?: string } | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    return Boolean(result?.ok);
  };
  const save = async () => {
    setBusy(true);
    if (report(await adminApi.lootSave(table.name, draft))) await load(table.name);
    setBusy(false);
  };
  const reset = async () => {
    if (!confirmReset) return setConfirmReset(true);
    setConfirmReset(false);
    setBusy(true);
    if (report(await adminApi.lootReset(table.name))) await load(table.name);
    setBusy(false);
  };
  const saveZones = async () => {
    setBusy(true);
    if (report(await adminApi.lootZones(zones))) await load(table.name);
    setBusy(false);
  };

  return (
    <div className="admin-loot">
      <nav className="admin-loot__tables">
        {data.tables.map((entry) => (
          <button
            key={entry.name}
            className={entry.name === table.name ? 'admin-loot__table admin-loot__table--active' : 'admin-loot__table'}
            onClick={() => select(entry)}
          >
            <span className="disp">{entry.label}</span>
            {entry.modified && <span className="mono admin-loot__modified">{t('MODIFIÉE')}</span>}
          </button>
        ))}
      </nav>
      <p className="muted admin-loot__used">
        {t('Utilisée par : {zones}', {
          zones: table.usedBy.length > 0 ? table.usedBy.map((zone) => t(zone)).join(', ') : t('aucune zone'),
        })}
      </p>

      <div className="admin-loot__money">
        <label className="admin-loot__check">
          <input
            type="checkbox"
            checked={draft.money !== false}
            onChange={(event) => setDraft({ ...draft, money: event.target.checked ? [0, 100] : false })}
          />
          <span className="label">{t('Argent')}</span>
        </label>
        {draft.money && (
          <>
            <input
              className="admin-input admin-input--small"
              type="number"
              min={0}
              value={draft.money[0]}
              aria-label={t('Argent minimum')}
              onChange={(event) => draft.money && setDraft({ ...draft, money: [toNumber(event.target.value), draft.money[1]] })}
            />
            <span className="muted">{t('à')}</span>
            <input
              className="admin-input admin-input--small"
              type="number"
              min={0}
              value={draft.money[1]}
              aria-label={t('Argent maximum')}
              onChange={(event) => draft.money && setDraft({ ...draft, money: [draft.money[0], toNumber(event.target.value)] })}
            />
            <span className="muted">$</span>
          </>
        )}
        <span className="admin-loot__scale">
          <button className="btn btn--small" onClick={() => scaleChances(0.5)}>{t('Chances ×0,5')}</button>
          <button className="btn btn--small" onClick={() => scaleChances(2)}>×2</button>
        </span>
      </div>

      <div className="admin-loot__head mono">
        <span>{t('OBJET')}</span>
        <span>{t('QTÉ MIN')}</span>
        <span>{t('QTÉ MAX')}</span>
        <span>{t('CHANCE %')}</span>
        <span />
      </div>
      <ul className="admin-loot__rows">
        {draft.drops.map((drop, index) => (
          <li key={index} className="admin-loot__row">
            <select
              className="admin-input"
              value={drop.item}
              aria-label={t('Objet')}
              onChange={(event) => updateDrop(index, { item: event.target.value })}
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
              value={drop.count[0]}
              aria-label={t('Quantité minimum')}
              onChange={(event) => updateDrop(index, { count: [toNumber(event.target.value), drop.count[1]] })}
            />
            <input
              className="admin-input"
              type="number"
              min={1}
              value={drop.count[1]}
              aria-label={t('Quantité maximum')}
              onChange={(event) => updateDrop(index, { count: [drop.count[0], toNumber(event.target.value)] })}
            />
            <input
              className="admin-input"
              type="number"
              min={0.1}
              max={100}
              step={0.1}
              value={drop.chance}
              aria-label={t('Chance en pour cent')}
              onChange={(event) => updateDrop(index, { chance: toNumber(event.target.value) })}
            />
            <button
              className="btn btn--small btn--danger"
              aria-label={t('Retirer la ligne')}
              onClick={() => setDraft({ ...draft, drops: draft.drops.filter((_, i) => i !== index) })}
            >
              ✕
            </button>
          </li>
        ))}
      </ul>
      <button
        className="btn btn--small"
        onClick={() =>
          setDraft({ ...draft, drops: [...draft.drops, { item: data.items[0]?.name ?? '', count: [1, 1], chance: 10 }] })
        }
      >
        {t('+ Ajouter un objet')}
      </button>

      <div className="admin-loot__actions">
        <button className="btn btn--small btn--primary" disabled={!dirty || busy} onClick={save}>
          {t('Enregistrer')}
        </button>
        <button className="btn btn--small" disabled={!dirty || busy} onClick={() => setDraft(copy(table))}>
          {t('Annuler')}
        </button>
        <button className="btn btn--small btn--danger" disabled={busy} onClick={reset}>
          {confirmReset ? t('Confirmer : valeurs par défaut') : t('Valeurs par défaut')}
        </button>
      </div>

      <span className="label admin-loot__section">{t('Butin des zones PvE')}</span>
      <ul className="admin-loot__zones">
        {data.zones.map((zone) => (
          <li key={zone.id} className="admin-loot__zone">
            <span className="admin-loot__zone-name">{t(zone.label)}</span>
            <select
              className="admin-input"
              value={zones[zone.id]}
              aria-label={t('Butin de {zone}', { zone: t(zone.label) })}
              onChange={(event) => setZones({ ...zones, [zone.id]: event.target.value })}
            >
              {data.tables.map((entry) => (
                <option key={entry.name} value={entry.name}>{entry.label}</option>
              ))}
            </select>
          </li>
        ))}
      </ul>
      <button className="btn btn--small btn--primary" disabled={!zonesDirty || busy} onClick={saveZones}>
        {t('Enregistrer les zones')}
      </button>
    </div>
  );
}
