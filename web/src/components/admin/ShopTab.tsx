import { useCallback, useEffect, useMemo, useState } from 'react';
import { adminApi } from '../../api/adminApi';
import { t, useLanguage, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { ShopAdminData, ShopAdminItem, ShopEntryDraft } from '../../types/admin';
import { formatMoney } from '../../utils/format';

/** Groupes de la liste, dans l'ordre de la page Boutique */
const SECTIONS: { type: string; label: string }[] = [
  { type: 'weapon', label: 'Armes' },
  { type: 'ammo', label: 'Munitions' },
  { type: 'attachment', label: 'Accessoires' },
  { type: 'consumable', label: 'Soins & équipement' },
  { type: 'vehicle', label: 'Véhicules' },
];

type Draft = Record<string, number>;

const toDraft = (items: ShopAdminItem[]): Draft => Object.fromEntries(items.map((item) => [item.name, item.price]));

const EMPTY_ENTRY: ShopEntryDraft = { item: '', count: 1, price: 0, level: 1 };

/** Prix de l'armurier, par lot vendu : enregistrés en base, appliqués tout de suite aux joueurs.
 *  On y ajoute aussi des objets que la boutique ne vendait pas (et on les retire). */
export function ShopTab() {
  useT();
  const language = useLanguage();
  const { actions } = useGame();
  const [data, setData] = useState<ShopAdminData | null>(null);
  const [draft, setDraft] = useState<Draft>({});
  const [search, setSearch] = useState('');
  const [confirmReset, setConfirmReset] = useState(false);
  const [busy, setBusy] = useState(false);
  const [adding, setAdding] = useState<ShopEntryDraft>(EMPTY_ENTRY);
  /** Objet ajouté dont on confirme le retrait */
  const [confirmRemove, setConfirmRemove] = useState<string | null>(null);

  const load = useCallback(async () => {
    const result = await adminApi.shop();
    if (!result?.ok) return actions.notify(result?.message ?? t('Prix de la boutique indisponibles.'), 'error');
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
  /** Champ vidé (0) : rien de gratuit, le serveur l'ignorerait */
  const incomplete = Object.values(changed).some((price) => price < 1);

  const visible = useMemo(() => {
    const query = search.trim().toLowerCase();
    return (data?.items ?? []).filter((item) => !query || t(item.label).toLowerCase().includes(query));
  }, [data, search, language]);

  /** Objets qu'on peut ajouter, par groupe de la page Boutique */
  const addableGroups = useMemo(
    () =>
      SECTIONS.map((section) => ({
        ...section,
        items: (data?.addable ?? [])
          .filter((item) => item.type === section.type)
          .sort((a, b) => t(a.label).localeCompare(t(b.label))),
      })).filter((section) => section.items.length > 0),
    [data, language],
  );

  if (!data) return <p className="muted">{t('Chargement des prix…')}</p>;

  const maxPrice = data.maxPrice;
  const limits = data.limits;
  const addedCount = data.items.filter((item) => item.custom).length;
  const clamp = (value: string, min: number, max: number) => Math.min(max, Math.max(min, Math.floor(Number(value) || 0)));
  const setPrice = (name: string, value: string) => setDraft({ ...draft, [name]: clamp(value, 0, maxPrice) });
  /** Multiplie les prix des objets affichés (ceux de la recherche) */
  const scale = (factor: number) => {
    const next = { ...draft };
    for (const item of visible) next[item.name] = Math.min(maxPrice, Math.max(1, Math.round(next[item.name] * factor)));
    setDraft(next);
  };

  const report = (result: { ok: boolean; message?: string } | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    return Boolean(result?.ok);
  };
  const save = async () => {
    setBusy(true);
    if (report(await adminApi.shopSave(changed))) await load();
    setBusy(false);
  };
  const reset = async () => {
    if (!confirmReset) return setConfirmReset(true);
    setConfirmReset(false);
    setBusy(true);
    if (report(await adminApi.shopReset())) await load();
    setBusy(false);
  };
  const canAdd = adding.item !== '' && adding.price >= 1 && adding.count >= 1 && addedCount < limits.maxAdded;
  const add = async () => {
    setBusy(true);
    if (report(await adminApi.shopAdd(adding))) {
      setAdding(EMPTY_ENTRY);
      await load();
    }
    setBusy(false);
  };
  const remove = async (name: string) => {
    if (confirmRemove !== name) return setConfirmRemove(name);
    setConfirmRemove(null);
    setBusy(true);
    if (report(await adminApi.shopRemove(name))) await load();
    setBusy(false);
  };

  return (
    <div className="admin-loot">
      <p className="muted admin-loot__used">
        {t('Prix du lot affiché, appliqué tout de suite à tous les joueurs. La reprise du receleur suit ce prix, sauf si elle est fixée dans l\'onglet Revente : en rouge, elle permet de gagner de l\'argent sans limite en achetant puis revendant.')}
      </p>

      <section className="admin-shop__add">
        <span className="label">
          {t('Ajouter un objet')}
          <span className="mono muted"> {addedCount}/{limits.maxAdded}</span>
        </span>
        <div className="admin-shop__add-head mono">
          <span>{t('OBJET')}</span>
          <span>{t('QTÉ')}</span>
          <span>{t('NIV.')}</span>
          <span>{t('PRIX $')}</span>
          <span />
        </div>
        <div className="admin-shop__add-row">
          <select
            className="admin-input"
            value={adding.item}
            aria-label={t('Objet à ajouter')}
            onChange={(event) => setAdding({ ...adding, item: event.target.value })}
          >
            <option value="">{t('Choisir un objet…')}</option>
            {addableGroups.map((group) => (
              <optgroup key={group.type} label={t(group.label)}>
                {group.items.map((item) => (
                  <option key={item.name} value={item.name}>{t(item.label)}</option>
                ))}
              </optgroup>
            ))}
          </select>
          <input
            className="admin-input"
            type="number"
            min={1}
            max={limits.maxCount}
            value={adding.count}
            aria-label={t('Quantité reçue')}
            onChange={(event) => setAdding({ ...adding, count: clamp(event.target.value, 1, limits.maxCount) })}
          />
          <input
            className="admin-input"
            type="number"
            min={1}
            max={limits.maxLevel}
            value={adding.level}
            aria-label={t('Niveau minimum')}
            onChange={(event) => setAdding({ ...adding, level: clamp(event.target.value, 1, limits.maxLevel) })}
          />
          <input
            className="admin-input"
            type="number"
            min={1}
            max={maxPrice}
            value={adding.price || ''}
            placeholder="0"
            aria-label={t('Prix du lot')}
            onChange={(event) => setAdding({ ...adding, price: clamp(event.target.value, 0, maxPrice) })}
          />
          <button className="btn btn--small btn--primary" disabled={!canAdd || busy} onClick={add}>
            {t('Ajouter')}
          </button>
        </div>
      </section>

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
        <span>{t('DÉFAUT')}</span>
        <span>{t('REVENTE')}</span>
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
                const label = item.count > 1 ? `${t(item.label)} x${item.count}` : t(item.label);
                const risky = price < 1 || (!item.resaleFollows && item.resale >= price);
                return (
                  <li key={item.name} className={risky ? 'admin-resale__row admin-resale__row--risky' : 'admin-resale__row'}>
                    <span className="admin-resale__name">
                      {item.custom && (
                        <button
                          className={confirmRemove === item.name ? 'admin-shop__remove admin-shop__remove--confirm' : 'admin-shop__remove'}
                          disabled={busy}
                          title={t('Retirer de la boutique')}
                          aria-label={t('Retirer {item} de la boutique', { item: label })}
                          onClick={() => remove(item.name)}
                          onBlur={() => setConfirmRemove(null)}
                        >
                          {confirmRemove === item.name ? t('Retirer ?') : '×'}
                        </button>
                      )}
                      {label}
                      {item.level > 1 && <span className="mono muted"> {t('NIV. {level}', { level: item.level })}</span>}
                      {item.custom && <span className="mono admin-loot__modified"> {t('AJOUTÉ')}</span>}
                      {price !== item.price && <span className="mono admin-loot__modified"> {t('MODIFIÉ')}</span>}
                    </span>
                    <span className="mono muted">{item.custom ? '—' : formatMoney(item.default)}</span>
                    <span className="mono muted">{formatMoney(item.resale)}</span>
                    <input
                      className="admin-input"
                      type="number"
                      min={1}
                      max={maxPrice}
                      value={price}
                      aria-label={t('Prix boutique de {item}', { item: label })}
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
        <button className="btn btn--small btn--primary" disabled={changedCount === 0 || incomplete || busy} onClick={save}>
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
