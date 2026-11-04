import { Fragment, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { adminApi } from '../../api/adminApi';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CodMapData, CvcArenaSpawns, FreeroamAdminData, FreeroamPlace, FreeroamSetting, MapPoint, PvpZone } from '../../types/admin';
import { RowButtons } from './FreeroamTab';

/** Rayon proposé pour une nouvelle carte Seven of Duty (mètres), bornes de server/modules/cod/cod_map_service.lua */
const DEFAULT_RADIUS = 80;
const MIN_RADIUS = 20;
const MAX_RADIUS = 500;

/** Rayon d'une zone du mode PvP (mètres), bornes de server/modules/freeroam/freeroam_config_service.lua */
const MIN_ZONE_RADIUS = 10;
const MAX_ZONE_RADIUS = 1000;

/** Équipes du CVC, dans l'ordre des départs (config/cvc.lua) */
const TEAM_LABELS = ['Équipe Alpha', 'Équipe Bravo'];

/** Joueurs des 1VS1 (GunFight, Bike), dans l'ordre des départs (config/gunfight.lua, config/bike.lua) */
const DUEL_LABELS = ['Joueur 1', 'Joueur 2'];

/**
 * Le panneau est démonté à sa fermeture, or il faut le fermer pour se déplacer :
 * le réglage ouvert et les positions pas encore enregistrées survivent à la réouverture.
 */
const remembered: { name: string | null; drafts: Record<string, FreeroamSetting> } = { name: null, drafts: {} };

const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

const without = (drafts: Record<string, FreeroamSetting>, name: string) => {
  const next = { ...drafts };
  delete next[name];
  return next;
};

const formatPoint = (point: MapPoint, flat: boolean) => {
  const coords = `${point.x.toFixed(1)}, ${point.y.toFixed(1)}, ${point.z.toFixed(1)}`;
  return flat ? coords : `${coords} · ${Math.round(point.w)}°`;
};

/** Listes de la carte qui n'ont pas assez de points pour le vote (points enregistrés) */
const missingLists = (lists: FreeroamSetting[]) =>
  lists.filter((list) => (list.value as MapPoint[]).length < (list.min ?? 0));

/** Distance entre le milieu des départs (centre de la zone de combat) et le point le plus loin ; null sans départ */
const farthestPoint = (lists: FreeroamSetting[]) => {
  const spawns = lists.filter((list) => /_(alpha|bravo)$/.test(list.name)).flatMap((list) => list.value as MapPoint[]);
  if (spawns.length === 0) return null;
  const x = spawns.reduce((sum, point) => sum + point.x, 0) / spawns.length;
  const y = spawns.reduce((sum, point) => sum + point.y, 0) / spawns.length;
  const distances = lists.flatMap((list) => (list.value as MapPoint[]).map((point) => Math.hypot(point.x - x, point.y - y)));
  return Math.max(...distances);
};

/** Positions des modes de jeu : un mode ou une carte à gauche, ses points à droite, enregistrés en base. */
export function PositionsTab() {
  useT();
  const { actions } = useGame();
  const [settings, setSettings] = useState<FreeroamSetting[] | null>(null);
  const [codMaps, setCodMaps] = useState<CodMapData[]>([]);
  const [removedMaps, setRemovedMaps] = useState<FreeroamAdminData['codMapsRemoved']>([]);
  const [creating, setCreating] = useState(false);
  const [name, setName] = useState(remembered.name);
  const [drafts, setDrafts] = useState(remembered.drafts);

  useEffect(() => {
    remembered.name = name;
    remembered.drafts = drafts;
  }, [name, drafts]);

  const load = useCallback(async () => {
    const result = await adminApi.freeroam();
    if (!result?.ok) return actions.notify(result?.message ?? t('Positions indisponibles.'), 'error');
    setSettings((Array.isArray(result.settings) ? result.settings : []).filter((entry) => entry.group !== 'vehicles'));
    setCodMaps(Array.isArray(result.codMaps) ? result.codMaps : []);
    setRemovedMaps(Array.isArray(result.codMapsRemoved) ? result.codMapsRemoved : []);
  }, [actions]);

  useEffect(() => {
    load();
  }, [load]);

  const pvp = useMemo(() => settings?.filter((entry) => entry.group === 'pvp') ?? [], [settings]);
  const modes = useMemo(() => settings?.filter((entry) => entry.group === 'positions') ?? [], [settings]);
  const cod =useMemo(() => settings?.filter((entry) => entry.group === 'cod') ?? [], [settings]);

  if (!settings) return <p className="muted admin-pos__empty">{t('Chargement des positions…')}</p>;
  const setting = settings.find((entry) => entry.name === name) ?? settings[0];
  if (!setting) return <p className="muted admin-pos__empty">{t('Positions indisponibles.')}</p>;

  const lists = setting.map ? cod.filter((entry) => entry.map === setting.map) : [];
  const map = codMaps.find((entry) => entry.id === setting.map);

  /** Autre carte : la liste en cours de modification, sinon la même qu'ici (Drapeaux, Sites de bombe...) */
  const selectMap = (id: string) => {
    const target = cod.filter((entry) => entry.map === id);
    const next = target.find((entry) => drafts[entry.name]) ?? target[lists.indexOf(setting)] ?? target[0];
    setCreating(false);
    if (next) setName(next.name);
  };

  /** Carte créée ou remise : on ouvre sa première liste */
  const openMap = async (id: string) => {
    await load();
    setCreating(false);
    setName(`cod_${id}_alpha`);
  };

  const restore = async (id: string) => {
    const result = await adminApi.codMapRestore(id);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    if (result?.ok) await openMap(id);
  };

  /** Les positions pas encore enregistrées d'une carte supprimée ne servent plus à rien */
  const forgetMap = async (id: string) => {
    setDrafts((current) => Object.fromEntries(Object.entries(current).filter(([, draft]) => draft.map !== id)));
    setName(null);
    await load();
  };

  return (
    <div className="admin-pos">
      <nav className="admin-pos__nav">
        {[
          { title: t('PvP'), entries: pvp },
          { title: t('Freeroam'), entries: modes },
        ].map((section) => (
          <Fragment key={section.title}>
            <span className="label admin-pos__nav-title">{section.title}</span>
            {section.entries.map((entry) => (
              <NavItem
                key={entry.name}
                label={entry.short ?? entry.label}
                active={!creating && entry === setting}
                dirty={Boolean(drafts[entry.name])}
                onClick={() => {
                  setCreating(false);
                  setName(entry.name);
                }}
              />
            ))}
          </Fragment>
        ))}
        <span className="label admin-pos__nav-title">{t('Seven of Duty')}</span>
        {codMaps.map((entry) => {
          const mapLists = cod.filter((list) => list.map === entry.id);
          const note = missingLists(mapLists).length > 0 ? t('Incomplète') : entry.enabled ? null : t('Hors vote');
          return (
            <NavItem
              key={entry.id}
              label={entry.label}
              note={note}
              active={!creating && setting.map === entry.id}
              dirty={mapLists.some((list) => drafts[list.name])}
              onClick={() => selectMap(entry.id)}
            />
          );
        })}
        <button className={creating ? 'admin-pos__item admin-pos__item--active' : 'admin-pos__item'} onClick={() => setCreating(true)}>
          <span className="admin-pos__item-label">{t('+ Nouvelle carte')}</span>
        </button>
        {removedMaps.length > 0 && <span className="label admin-pos__nav-title">{t('Cartes supprimées')}</span>}
        {removedMaps.map((entry) => (
          <div key={entry.id} className="admin-pos__removed">
            <span className="admin-pos__item-label">{entry.label}</span>
            <button className="btn btn--small" onClick={() => restore(entry.id)}>{t('Remettre')}</button>
          </div>
        ))}
      </nav>
      <section className="admin-pos__panel">
        {creating ? (
          <MapForm key="new" map={null} lists={[]} onSaved={openMap} onCancel={() => setCreating(false)} />
        ) : (
          <>
            {map && <MapForm key={map.id} map={map} lists={lists} onSaved={load} onDeleted={() => forgetMap(map.id)} />}
            <SettingPanel
              key={setting.name}
              setting={setting}
              draft={drafts[setting.name] ?? setting}
              lists={lists}
              drafts={drafts}
              onSelect={setName}
              onEdit={(next) => setDrafts((current) => (same(next.value, setting.value) ? without(current, next.name) : { ...current, [next.name]: next }))}
              onDiscard={() => setDrafts((current) => without(current, setting.name))}
              onReload={load}
              resettable={!map?.custom}
            />
          </>
        )}
      </section>
    </div>
  );
}

function NavItem({ label, note, active, dirty, onClick }: { label: string; note?: string | null; active: boolean; dirty: boolean; onClick: () => void }) {
  return (
    <button className={active ? 'admin-pos__item admin-pos__item--active' : 'admin-pos__item'} onClick={onClick}>
      <span className="admin-pos__item-label">{label}</span>
      {note && <span className="mono admin-pos__note">{note}</span>}
      {dirty && <span className="admin-pos__dot" />}
    </button>
  );
}

interface MapFormProps {
  /** null : création d'une carte */
  map: CodMapData | null;
  lists: FreeroamSetting[];
  onSaved: (id: string) => Promise<void>;
  onCancel?: () => void;
  onDeleted?: () => Promise<void>;
}

/** Nom, lieu, rayon et présence au vote d'une carte Seven of Duty ; création et suppression. */
function MapForm({ map, lists, onSaved, onCancel, onDeleted }: MapFormProps) {
  useT();
  const { actions } = useGame();
  const [label, setLabel] = useState(map?.label ?? '');
  const [place, setPlace] = useState(map?.place ?? '');
  const [radius, setRadius] = useState(String(map?.radius ?? DEFAULT_RADIUS));
  const [enabled, setEnabled] = useState(map?.enabled ?? true);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [busy, setBusy] = useState(false);

  const size = Number(radius);
  const valid = label.trim() !== '' && size >= MIN_RADIUS && size <= MAX_RADIUS;
  const dirty = !map || label !== map.label || place !== map.place || size !== map.radius || enabled !== map.enabled;
  const missing = missingLists(lists);
  const farthest = farthestPoint(lists);

  const report = (result: { ok: boolean; message?: string } | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    return Boolean(result?.ok);
  };
  const save = async () => {
    setBusy(true);
    const result = await adminApi.codMapSave({ id: map?.id, label, place, radius: size, enabled });
    if (report(result) && result?.id) await onSaved(result.id);
    setBusy(false);
  };
  const remove = async () => {
    if (!map) return;
    if (!confirmDelete) return setConfirmDelete(true);
    setBusy(true);
    if (report(await adminApi.codMapDelete(map.id))) await onDeleted?.();
    else setBusy(false);
  };

  return (
    <div className="admin-map">
      <header className="admin-map__head">
        <h2 className="disp admin-pos__title">{map ? map.label : t('Nouvelle carte')}</h2>
        {map && (
          <button className="btn btn--small btn--danger admin-pos__reset" disabled={busy} onClick={remove}>
            {confirmDelete ? t('Confirmer la suppression') : t('Supprimer la carte')}
          </button>
        )}
      </header>
      <div className="admin-map__fields">
        <label className="admin-map__field admin-map__field--wide">
          <span className="label">{t('Nom')}</span>
          <input className="admin-input" maxLength={40} value={label} onChange={(event) => setLabel(event.target.value)} />
        </label>
        <label className="admin-map__field admin-map__field--wide">
          <span className="label">{t('Lieu')}</span>
          <input className="admin-input" maxLength={40} value={place} onChange={(event) => setPlace(event.target.value)} />
        </label>
        <label className="admin-map__field">
          <span className="label">{t('Rayon (m)')}</span>
          <input
            className="admin-input admin-input--small mono"
            type="number"
            min={MIN_RADIUS}
            max={MAX_RADIUS}
            value={radius}
            onChange={(event) => setRadius(event.target.value)}
          />
        </label>
        <button className={enabled ? 'btn btn--small btn--primary' : 'btn btn--small'} onClick={() => setEnabled(!enabled)}>
          {enabled ? t('Dans le vote') : t('Hors vote')}
        </button>
        <button className="btn btn--small btn--primary" disabled={!valid || !dirty || busy} onClick={save}>
          {map ? t('Enregistrer') : t('Créer la carte')}
        </button>
        {onCancel && <button className="btn btn--small" onClick={onCancel}>{t('Annuler')}</button>}
      </div>
      {map ? (
        <p className={missing.length > 0 ? 'admin-map__status admin-map__status--warn' : 'admin-map__status muted'}>
          {missing.length > 0
            ? t('Incomplète, pas proposée au vote. À placer : {lists}.', {
                lists: missing.map((list) => `${list.short ?? list.label} (${(list.value as MapPoint[]).length}/${list.min})`).join(', '),
              })
            : enabled
              ? t('Prête : proposée au vote.')
              : t('Prête, mais retirée du vote.')}
          {farthest !== null && (
            <span className={farthest > size ? 'admin-map__status--warn' : undefined}>
              {' '}{t('Point le plus loin : {distance} m du centre.', { distance: Math.round(farthest) })}
            </span>
          )}
        </p>
      ) : (
        <p className="muted admin-map__status">
          {t('Crée la carte, puis place ses points depuis cet onglet : elle entre au vote dès qu\'elle a 2 apparitions par camp, 3 drapeaux et 2 sites de bombe.')}
        </p>
      )}
    </div>
  );
}

interface SettingPanelProps {
  setting: FreeroamSetting;
  draft: FreeroamSetting;
  /** listes de la même carte Seven of Duty (onglets) */
  lists: FreeroamSetting[];
  drafts: Record<string, FreeroamSetting>;
  onSelect: (name: string) => void;
  onEdit: (draft: FreeroamSetting) => void;
  onDiscard: () => void;
  onReload: () => Promise<void>;
  /** a des valeurs dans un fichier de config auxquelles revenir */
  resettable: boolean;
}

function SettingPanel({ setting, draft, lists, drafts, onSelect, onEdit, onDiscard, onReload, resettable }: SettingPanelProps) {
  useT();
  const { actions } = useGame();
  const [confirmReset, setConfirmReset] = useState(false);
  const [busy, setBusy] = useState(false);
  const dirty = !same(setting.value, draft.value);

  const report = (result: { ok: boolean; message?: string } | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    return Boolean(result?.ok);
  };
  const save = async () => {
    setBusy(true);
    if (report(await adminApi.freeroamSave(draft))) {
      onDiscard();
      await onReload();
    }
    setBusy(false);
  };
  const reset = async () => {
    if (!confirmReset) return setConfirmReset(true);
    setConfirmReset(false);
    setBusy(true);
    if (report(await adminApi.freeroamReset(setting.name))) {
      onDiscard();
      await onReload();
    }
    setBusy(false);
  };

  return (
    <div className="admin-pos__setting">
      <header className="admin-pos__head">
        {!setting.map && (
          <h2 className="disp admin-pos__title">
            {setting.short ?? setting.label}
            {setting.modified && <span className="mono admin-loot__modified">{t('MODIFIÉ')}</span>}
          </h2>
        )}
        {lists.length > 0 && (
          <nav className="admin-pos__lists">
            {lists.map((entry) => (
              <button
                key={entry.name}
                className={entry === setting ? 'admin-pos__list admin-pos__list--active' : 'admin-pos__list'}
                onClick={() => onSelect(entry.name)}
              >
                {entry.short ?? entry.label}
                <span className="mono admin-pos__count">{(entry.value as MapPoint[]).length}/{entry.min}</span>
                {drafts[entry.name] && <span className="admin-pos__dot" />}
              </button>
            ))}
          </nav>
        )}
        <p className="muted admin-pos__hint">{setting.hint}</p>
      </header>

      <div className="admin-pos__body">
        <PositionEditor setting={setting} draft={draft} onChange={onEdit} />
      </div>

      <footer className="admin-pos__foot">
        <button className="btn btn--small btn--primary" disabled={!dirty || busy} onClick={save}>{t('Enregistrer')}</button>
        <button className="btn btn--small" disabled={!dirty || busy} onClick={onDiscard}>{t('Annuler')}</button>
        {dirty && !confirmReset && <span className="admin-pos__unsaved">{t('Non enregistré')}</span>}
        {resettable && (
          <button className="btn btn--small btn--danger admin-pos__reset" disabled={!setting.modified || busy} onClick={reset}>
            {confirmReset ? t('Confirmer : valeurs par défaut') : t('Valeurs par défaut')}
          </button>
        )}
      </footer>
    </div>
  );
}

function PositionEditor({ setting, draft, onChange }: { setting: FreeroamSetting; draft: FreeroamSetting; onChange: (draft: FreeroamSetting) => void }) {
  useT();
  switch (draft.kind) {
    case 'points':
      return (
        <PointList
          points={draft.value}
          saved={setting.value as MapPoint[]}
          name={draft.point ?? t('Départ')}
          letters={draft.letters === true}
          flat={draft.flat === true}
          onChange={(value) => onChange({ ...draft, value })}
        />
      );
    case 'pair':
      return <PairList points={draft.value} saved={setting.value as MapPoint[]} onChange={(value) => onChange({ ...draft, value })} />;
    case 'arenas':
      return <ArenaList arenas={draft.value} saved={setting.value as CvcArenaSpawns[]} onChange={(value) => onChange({ ...draft, value })} />;
    case 'places':
      return <PlaceList places={draft.value} saved={setting.value as FreeroamPlace[]} onChange={(value) => onChange({ ...draft, value })} />;
    case 'zones':
      return <ZoneList zones={draft.value} saved={setting.value as PvpZone[]} name={draft.point ?? t('Apparition')} onChange={(value) => onChange({ ...draft, value })} />;
    default:
      return null;
  }
}

/** Position actuelle de l'admin, ou null (message d'erreur affiché) */
function usePosition() {
  const { actions } = useGame();
  return useCallback(async () => {
    const result = await adminApi.position();
    if (!result?.ok || !result.point) {
      actions.notify(t('Position indisponible.'), 'error');
      return null;
    }
    return result.point;
  }, [actions]);
}

interface PointRowProps {
  label: string;
  point: MapPoint;
  /** valeur enregistrée : la ligne est marquée tant qu'elle en diffère */
  saved: MapPoint | undefined;
  onChange: (point: MapPoint) => void;
  /** sans direction : le cap n'est pas affiché et ne compte pas */
  flat?: boolean;
  /** boutons en plus, en fin de ligne */
  children?: ReactNode;
}

/** Une position : coordonnées, « Ma position » (la remplace par celle de l'admin) et « Y aller ». */
function PointRow({ label, point, saved, onChange, flat = false, children }: PointRowProps) {
  useT();
  const { actions } = useGame();
  const position = usePosition();
  const place = async () => {
    const next = await position();
    if (next) onChange(flat ? { ...next, w: 0 } : next);
  };
  return (
    <li className={same(point, saved) ? 'admin-point' : 'admin-point admin-point--changed'}>
      <span className="admin-point__text">
        <span className="admin-point__label">{label}</span>
        <span className="mono muted admin-point__coords">{formatPoint(point, flat)}</span>
      </span>
      <button className="btn btn--small btn--primary" onClick={place}>{t('Ma position')}</button>
      <button className="btn btn--small" onClick={() => actions.adminAction({ action: 'gotoPoint', ...point })}>{t('Y aller')}</button>
      {children}
    </li>
  );
}

interface PointListProps {
  points: MapPoint[];
  saved: MapPoint[];
  /** nom d'un point : « Drapeau », « Apparition »... */
  name: string;
  /** numéroté A, B, C (drapeaux, sites de bombe) plutôt que 1, 2, 3 */
  letters: boolean;
  /** points sans direction */
  flat?: boolean;
  onChange: (points: MapPoint[]) => void;
}

function PointList({ points, saved, name, letters, flat = false, onChange }: PointListProps) {
  useT();
  const position = usePosition();
  const add = async () => {
    const point = await position();
    if (point) onChange([...points, flat ? { ...point, w: 0 } : point]);
  };
  return (
    <>
      <ul className="admin-points">
        {points.map((point, index) => (
          <PointRow
            key={index}
            label={`${name} ${letters ? String.fromCharCode(65 + index) : index + 1}`}
            point={point}
            saved={saved[index]}
            flat={flat}
            onChange={(next) => onChange(points.map((entry, i) => (i === index ? next : entry)))}
          >
            <RowButtons index={index} list={points} onChange={onChange} />
          </PointRow>
        ))}
      </ul>
      <button className="btn btn--small admin-pos__add" onClick={add}>{t('+ Ajouter ma position')}</button>
    </>
  );
}

/** Deux départs fixes (1VS1) : pas d'ajout ni de retrait. */
function PairList({ points, saved, onChange }: { points: [MapPoint, MapPoint]; saved: MapPoint[]; onChange: (points: [MapPoint, MapPoint]) => void }) {
  useT();
  return (
    <ul className="admin-points">
      {points.map((point, index) => (
        <PointRow
          key={index}
          label={t(DUEL_LABELS[index])}
          point={point}
          saved={saved[index]}
          onChange={(next) => onChange((index === 0 ? [next, points[1]] : [points[0], next]) as [MapPoint, MapPoint])}
        />
      ))}
    </ul>
  );
}

function ArenaList({ arenas, saved, onChange }: { arenas: CvcArenaSpawns[]; saved: CvcArenaSpawns[]; onChange: (arenas: CvcArenaSpawns[]) => void }) {
  useT();
  const setSpawn = (arenaIndex: number, team: number, point: MapPoint) =>
    onChange(
      arenas.map((arena, i) =>
        i === arenaIndex
          ? { ...arena, spawns: (team === 0 ? [point, arena.spawns[1]] : [arena.spawns[0], point]) as [MapPoint, MapPoint] }
          : arena,
      ),
    );
  return (
    <>
      {arenas.map((arena, arenaIndex) => (
        <div key={arena.label} className="admin-pos__group">
          <span className="label">{t(arena.label)}</span>
          <ul className="admin-points">
            {arena.spawns.map((spawn, team) => (
              <PointRow
                key={team}
                label={t(TEAM_LABELS[team])}
                point={spawn}
                saved={saved[arenaIndex]?.spawns[team]}
                onChange={(point) => setSpawn(arenaIndex, team, point)}
              />
            ))}
          </ul>
        </div>
      ))}
    </>
  );
}

/** Zones du mode PvP : centre, rayon et points d'apparition de chacune. */
function ZoneList({ zones, saved, name, onChange }: { zones: PvpZone[]; saved: PvpZone[]; name: string; onChange: (zones: PvpZone[]) => void }) {
  useT();
  const setZone = (id: string, changes: Partial<PvpZone>) =>
    onChange(zones.map((zone) => (zone.id === id ? { ...zone, ...changes } : zone)));
  return (
    <>
      {zones.map((zone) => {
        const before = saved.find((entry) => entry.id === zone.id);
        return (
          <div key={zone.id} className="admin-pos__group">
            <div className="admin-pos__zone-head">
              <span className="label">{t(zone.label)}</span>
              <label className="admin-pos__radius">
                <span className="label">{t('Rayon (m)')}</span>
                <input
                  className="admin-input admin-input--small mono"
                  type="number"
                  min={MIN_ZONE_RADIUS}
                  max={MAX_ZONE_RADIUS}
                  value={zone.radius || ''}
                  onChange={(event) => setZone(zone.id, { radius: Number(event.target.value) })}
                />
              </label>
            </div>
            <ul className="admin-points">
              <PointRow label={t('Centre')} point={zone.center} saved={before?.center} flat onChange={(center) => setZone(zone.id, { center })} />
            </ul>
            {zone.spawns && (
              <PointList
                points={zone.spawns}
                saved={before?.spawns ?? []}
                name={name}
                letters={false}
                onChange={(spawns) => setZone(zone.id, { spawns })}
              />
            )}
          </div>
        );
      })}
    </>
  );
}

/** Emplacements rangés par groupe, le début de leur libellé (« Groupe · Nom ») : PNJ et tableaux du classement, zones safe */
function PlaceList({ places, saved, onChange }: { places: FreeroamPlace[]; saved: FreeroamPlace[]; onChange: (places: FreeroamPlace[]) => void }) {
  useT();
  const groupOf = (place: FreeroamPlace) => place.label.split(' · ')[0];
  const groups = [...new Set(places.map(groupOf))].map((title) => ({ title, entries: places.filter((place) => groupOf(place) === title) }));
  return (
    <>
      {groups.map((group) => (
        <div key={group.title} className="admin-pos__group">
          <span className="label">{t(group.title)}</span>
          <ul className="admin-points">
            {group.entries.map((place) => (
              <PointRow
                key={place.key}
                label={t(place.label.split(' · ').pop() ?? place.label)}
                point={place.coords}
                saved={saved.find((entry) => entry.key === place.key)?.coords}
                onChange={(coords) => onChange(places.map((entry) => (entry.key === place.key ? { ...entry, coords } : entry)))}
              />
            ))}
          </ul>
        </div>
      ))}
    </>
  );
}
