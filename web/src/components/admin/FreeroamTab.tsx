import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { adminApi } from '../../api/adminApi';
import { useGame } from '../../store/GameContext';
import type {
  ChaseMatchInfo,
  ChasePhase,
  CvcArenaSpawns,
  FreeroamAdminData,
  FreeroamPlace,
  FreeroamSetting,
  FreeroamVehicle,
  MapPoint,
} from '../../types/admin';

const PHASE_LABELS: Record<ChasePhase, string> = {
  vote: 'Vote des véhicules',
  countdown: 'Départ',
  running: 'En course',
  pause: 'Fin de manche',
  ended: 'Terminée',
};

const ROLE_LABELS = { thief: 'VOLEUR', cop: 'POLICIER' };

/** Équipes du CVC, dans l'ordre des départs (config/cvc.lua) */
const TEAM_LABELS = ['Équipe Alpha', 'Équipe Bravo'];

/** Joueurs des 1VS1 (GunFight, Bike), dans l'ordre des départs (config/gunfight.lua, config/bike.lua) */
const DUEL_LABELS = ['Joueur 1', 'Joueur 2'];

/** Les courses en cours sont relues à ce rythme (ms) tant que l'onglet est ouvert */
const REFRESH_INTERVAL = 5000;

const copy = (setting: FreeroamSetting): FreeroamSetting => JSON.parse(JSON.stringify(setting));

const formatPoint = (point: MapPoint) =>
  `${point.x.toFixed(1)}, ${point.y.toFixed(1)}, ${point.z.toFixed(1)} · ${Math.round(point.w)}°`;

/** Freeroam : courses poursuite en cours (mode spectateur), véhicules et positions des modes de jeu, enregistrés en base. */
export function FreeroamTab() {
  const { state, actions } = useGame();
  const [data, setData] = useState<FreeroamAdminData | null>(null);

  const load = useCallback(async () => {
    const result = await adminApi.freeroam();
    if (!result?.ok) return actions.notify(result?.message ?? 'Réglages du Freeroam indisponibles.', 'error');
    setData(result);
  }, [actions]);

  /** Courses seulement : ne touche pas aux réglages en cours de modification */
  const refreshChases = useCallback(async () => {
    const result = await adminApi.freeroam();
    if (result?.ok) setData((current) => (current ? { ...current, chases: result.chases, chaseQueue: result.chaseQueue } : result));
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    const timer = window.setInterval(refreshChases, REFRESH_INTERVAL);
    return () => window.clearInterval(timer);
  }, [refreshChases]);

  const settings = useMemo(() => (Array.isArray(data?.settings) ? data.settings : []), [data?.settings]);
  if (!data) return <p className="muted">Chargement du Freeroam…</p>;

  const chases = Array.isArray(data.chases) ? data.chases : [];
  const spectating = state.admin.self.spectating;
  const spectate = async (target: number) => {
    if (await actions.adminAction({ action: 'spectate', target })) refreshChases();
  };

  return (
    <div className="admin-freeroam">
      <div className="admin-freeroam__head">
        <span className="label">Courses poursuite en cours</span>
        <button className="btn btn--small" onClick={refreshChases}>Actualiser</button>
      </div>
      {spectating && <SpectateBar name={spectating} onStop={() => actions.adminAction({ action: 'spectateStop' })} />}
      {chases.length > 0 ? (
        <ul className="admin-chases">
          {chases.map((match) => (
            <ChaseCard key={match.id} match={match} spectating={spectating} onSpectate={spectate} />
          ))}
        </ul>
      ) : (
        <p className="muted admin-empty">Aucune course en cours.</p>
      )}
      <p className="muted admin-freeroam__queue">
        {data.chaseQueue > 0 ? `${data.chaseQueue} joueur(s) dans la file d'attente.` : "Personne dans la file d'attente."}
        {' '}Pour regarder un joueur hors course : onglet Joueurs, bouton « Regarder ».
      </p>

      <SettingsSection title="Véhicules des modes de jeu" settings={settings.filter((s) => s.group === 'vehicles')} onSaved={load} />
      <SettingsSection title="Positions" settings={settings.filter((s) => s.group === 'positions')} onSaved={load} />
    </div>
  );
}

/** Mode spectateur en cours : rappel des touches et arrêt. */
export function SpectateBar({ name, onStop }: { name: string; onStop: () => void }) {
  return (
    <div className="admin-spectate">
      <span className="admin-spectate__text">
        <span className="disp">Tu regardes {name}</span>
        <span className="muted">Retour arrière : quitter · ← → : autre joueur au même endroit</span>
      </span>
      <button className="btn btn--small btn--danger" onClick={onStop}>Arrêter</button>
    </div>
  );
}

interface ChaseCardProps {
  match: ChaseMatchInfo;
  spectating: string | false;
  onSpectate: (target: number) => void;
}

function ChaseCard({ match, spectating, onSpectate }: ChaseCardProps) {
  return (
    <li className="admin-chase">
      <header className="admin-chase__head">
        <span className="disp">Course n°{match.id}</span>
        <span className="mono muted">
          {match.round > 0 ? `MANCHE ${match.round}/2 · ` : ''}
          {PHASE_LABELS[match.phase].toUpperCase()}
        </span>
      </header>
      {match.players.map((player) => (
        <div key={player.id} className="admin-chase__player">
          <span className="mono admin-player__id">{player.id}</span>
          <span className="admin-player__name">{player.name}</span>
          {player.role && (
            <span className={`mono admin-chase__role admin-chase__role--${player.role}`}>{ROLE_LABELS[player.role]}</span>
          )}
          <span className="mono muted" title="Manches gagnées · avertissements PIT">
            {player.score} pt · {player.warns} PIT
          </span>
          <button className="btn btn--small" disabled={spectating === player.name} onClick={() => onSpectate(player.id)}>
            {spectating === player.name ? 'Regardé' : 'Regarder'}
          </button>
        </div>
      ))}
    </li>
  );
}

// ---------------------------------------------------------------------------
// Réglages : un groupe (véhicules ou positions), un réglage affiché à la fois
// ---------------------------------------------------------------------------

interface SettingsSectionProps {
  title: string;
  settings: FreeroamSetting[];
  /** relit les réglages après un enregistrement */
  onSaved: () => Promise<void>;
}

function SettingsSection({ title, settings, onSaved }: SettingsSectionProps) {
  const { actions } = useGame();
  const [name, setName] = useState<string | null>(null);
  const setting = settings.find((entry) => entry.name === name) ?? settings[0] ?? null;
  const [draft, setDraft] = useState<FreeroamSetting | null>(null);
  const [confirmReset, setConfirmReset] = useState(false);
  const [busy, setBusy] = useState(false);

  // Nouveau réglage choisi ou relu après un enregistrement : le brouillon repart de lui
  useEffect(() => {
    setDraft(setting ? copy(setting) : null);
    setConfirmReset(false);
  }, [setting]);

  const dirty = useMemo(() => Boolean(setting && draft && JSON.stringify(setting.value) !== JSON.stringify(draft.value)), [setting, draft]);
  if (!setting || !draft || draft.name !== setting.name) return null;

  const report = (result: { ok: boolean; message?: string } | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    return Boolean(result?.ok);
  };
  const save = async () => {
    setBusy(true);
    if (report(await adminApi.freeroamSave(draft))) await onSaved();
    setBusy(false);
  };
  const reset = async () => {
    if (!confirmReset) return setConfirmReset(true);
    setConfirmReset(false);
    setBusy(true);
    if (report(await adminApi.freeroamReset(setting.name))) await onSaved();
    setBusy(false);
  };

  return (
    <>
      <span className="label admin-loot__section">{title}</span>
      <nav className="admin-loot__tables">
        {settings.map((entry) => (
          <button
            key={entry.name}
            className={entry.name === setting.name ? 'admin-loot__table admin-loot__table--active' : 'admin-loot__table'}
            onClick={() => setName(entry.name)}
          >
            <span className="disp">{entry.label}</span>
            {entry.modified && <span className="mono admin-loot__modified">MODIFIÉ</span>}
          </button>
        ))}
      </nav>
      <p className="muted admin-loot__used">{setting.hint}</p>

      <SettingEditor draft={draft} onChange={setDraft} />

      <div className="admin-loot__actions">
        <button className="btn btn--small btn--primary" disabled={!dirty || busy} onClick={save}>
          Enregistrer
        </button>
        <button className="btn btn--small" disabled={!dirty || busy} onClick={() => setDraft(copy(setting))}>
          Annuler
        </button>
        <button className="btn btn--small btn--danger" disabled={busy} onClick={reset}>
          {confirmReset ? 'Confirmer : valeurs par défaut' : 'Valeurs par défaut'}
        </button>
      </div>
    </>
  );
}

function SettingEditor({ draft, onChange }: { draft: FreeroamSetting; onChange: (draft: FreeroamSetting) => void }) {
  switch (draft.kind) {
    case 'vehicles':
      return <VehicleList vehicles={draft.value} category={draft.category} onChange={(value) => onChange({ ...draft, value })} />;
    case 'model':
      return (
        <input
          className="admin-input mono"
          placeholder="Modèle (ex : granger)"
          value={draft.value}
          aria-label="Modèle du véhicule"
          onChange={(event) => onChange({ ...draft, value: event.target.value.trim().toLowerCase() })}
        />
      );
    case 'points':
      return <PointList points={draft.value} onChange={(value) => onChange({ ...draft, value })} />;
    case 'pair':
      return <PairList points={draft.value} onChange={(value) => onChange({ ...draft, value })} />;
    case 'arenas':
      return <ArenaList arenas={draft.value} onChange={(value) => onChange({ ...draft, value })} />;
    case 'places':
      return <PlaceList places={draft.value} onChange={(value) => onChange({ ...draft, value })} />;
  }
}

// ---------------------------------------------------------------------------
// Véhicules
// ---------------------------------------------------------------------------

interface VehicleListProps {
  vehicles: FreeroamVehicle[];
  /** une colonne de plus pour la catégorie (menu Freeroam) */
  category: boolean;
  onChange: (vehicles: FreeroamVehicle[]) => void;
}

function VehicleList({ vehicles, category, onChange }: VehicleListProps) {
  const categories = useMemo(() => [...new Set(vehicles.map((vehicle) => vehicle.category).filter(Boolean))], [vehicles]);
  const update = (index: number, patch: Partial<FreeroamVehicle>) =>
    onChange(vehicles.map((vehicle, i) => (i === index ? { ...vehicle, ...patch } : vehicle)));
  const rowClass = category ? 'admin-vehicles__row admin-vehicles__row--category' : 'admin-vehicles__row';

  return (
    <>
      <div className={`${rowClass} admin-vehicles__head mono`}>
        <span>MODÈLE</span>
        <span>NOM AFFICHÉ</span>
        {category && <span>CATÉGORIE</span>}
        <span />
      </div>
      <ul className="admin-vehicles">
        {vehicles.map((vehicle, index) => (
          <li key={index} className={rowClass}>
            <input
              className="admin-input mono"
              value={vehicle.model}
              placeholder="ex : sultan"
              aria-label="Modèle"
              onChange={(event) => update(index, { model: event.target.value.trim().toLowerCase() })}
            />
            <input
              className="admin-input"
              value={vehicle.label}
              maxLength={40}
              aria-label="Nom affiché"
              onChange={(event) => update(index, { label: event.target.value })}
            />
            {category && (
              <input
                className="admin-input"
                value={vehicle.category ?? ''}
                maxLength={40}
                list="admin-vehicle-categories"
                aria-label="Catégorie"
                onChange={(event) => update(index, { category: event.target.value })}
              />
            )}
            <RowButtons index={index} list={vehicles} onChange={onChange} />
          </li>
        ))}
      </ul>
      {category && (
        <datalist id="admin-vehicle-categories">
          {categories.map((name) => (
            <option key={name} value={name} />
          ))}
        </datalist>
      )}
      <button
        className="btn btn--small"
        onClick={() => onChange([...vehicles, { model: '', label: '', ...(category ? { category: categories[0] ?? 'Voitures' } : {}) }])}
      >
        + Ajouter un véhicule
      </button>
    </>
  );
}

/** Monter, descendre, retirer (jamais le dernier : une liste ne peut pas être vide). */
function RowButtons<T>({ index, list, onChange }: { index: number; list: T[]; onChange: (list: T[]) => void }) {
  const move = (offset: number) => {
    const next = [...list];
    const [entry] = next.splice(index, 1);
    next.splice(index + offset, 0, entry);
    onChange(next);
  };
  return (
    <span className="admin-vehicles__buttons">
      <button className="btn btn--small" aria-label="Monter" disabled={index === 0} onClick={() => move(-1)}>↑</button>
      <button className="btn btn--small" aria-label="Descendre" disabled={index === list.length - 1} onClick={() => move(1)}>↓</button>
      <button
        className="btn btn--small btn--danger"
        aria-label="Retirer"
        disabled={list.length <= 1}
        onClick={() => onChange(list.filter((_, i) => i !== index))}
      >
        ✕
      </button>
    </span>
  );
}

// ---------------------------------------------------------------------------
// Positions
// ---------------------------------------------------------------------------

/** Position actuelle de l'admin, ou null (message d'erreur affiché) */
function usePosition() {
  const { actions } = useGame();
  return useCallback(async () => {
    const result = await adminApi.position();
    if (!result?.ok || !result.point) {
      actions.notify('Position indisponible.', 'error');
      return null;
    }
    return result.point;
  }, [actions]);
}

interface PointRowProps {
  label: string;
  point: MapPoint;
  onChange: (point: MapPoint) => void;
  /** boutons en plus, en fin de ligne */
  children?: ReactNode;
}

/** Une position : coordonnées, « Ma position » (la remplace par celle de l'admin) et « Y aller ». */
function PointRow({ label, point, onChange, children }: PointRowProps) {
  const { actions } = useGame();
  const position = usePosition();
  const place = async () => {
    const next = await position();
    if (next) onChange(next);
  };
  return (
    <li className={children ? 'admin-point admin-point--list' : 'admin-point'}>
      <span className="admin-point__label">{label}</span>
      <span className="mono muted admin-point__coords">{formatPoint(point)}</span>
      <button className="btn btn--small btn--primary" onClick={place}>Ma position</button>
      <button className="btn btn--small" onClick={() => actions.adminAction({ action: 'gotoPoint', ...point })}>Y aller</button>
      {children}
    </li>
  );
}

function PointList({ points, onChange }: { points: MapPoint[]; onChange: (points: MapPoint[]) => void }) {
  const position = usePosition();
  const add = async () => {
    const point = await position();
    if (point) onChange([...points, point]);
  };
  return (
    <>
      <ul className="admin-points">
        {points.map((point, index) => (
          <PointRow
            key={index}
            label={`Départ ${index + 1}`}
            point={point}
            onChange={(next) => onChange(points.map((entry, i) => (i === index ? next : entry)))}
          >
            <RowButtons index={index} list={points} onChange={onChange} />
          </PointRow>
        ))}
      </ul>
      <button className="btn btn--small" onClick={add}>+ Ajouter ma position</button>
    </>
  );
}

/** Deux départs fixes (1VS1 GunFight) : pas d'ajout ni de retrait. */
function PairList({ points, onChange }: { points: [MapPoint, MapPoint]; onChange: (points: [MapPoint, MapPoint]) => void }) {
  return (
    <ul className="admin-points">
      {points.map((point, index) => (
        <PointRow
          key={index}
          label={DUEL_LABELS[index]}
          point={point}
          onChange={(next) => onChange((index === 0 ? [next, points[1]] : [points[0], next]) as [MapPoint, MapPoint])}
        />
      ))}
    </ul>
  );
}

function ArenaList({ arenas, onChange }: { arenas: CvcArenaSpawns[]; onChange: (arenas: CvcArenaSpawns[]) => void }) {
  const setSpawn = (arenaIndex: number, team: number, point: MapPoint) =>
    onChange(
      arenas.map((arena, i) =>
        i === arenaIndex
          ? { ...arena, spawns: (team === 0 ? [point, arena.spawns[1]] : [arena.spawns[0], point]) as [MapPoint, MapPoint] }
          : arena,
      ),
    );
  return (
    <div className="admin-arenas">
      {arenas.map((arena, arenaIndex) => (
        <div key={arena.label} className="admin-arena">
          <span className="disp admin-arena__label">{arena.label}</span>
          <ul className="admin-points">
            {arena.spawns.map((spawn, team) => (
              <PointRow key={team} label={TEAM_LABELS[team]} point={spawn} onChange={(point) => setSpawn(arenaIndex, team, point)} />
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}

function PlaceList({ places, onChange }: { places: FreeroamPlace[]; onChange: (places: FreeroamPlace[]) => void }) {
  return (
    <ul className="admin-points">
      {places.map((place, index) => (
        <PointRow
          key={place.key}
          label={place.label}
          point={place.coords}
          onChange={(coords) => onChange(places.map((entry, i) => (i === index ? { ...entry, coords } : entry)))}
        />
      ))}
    </ul>
  );
}
