import { useCallback, useEffect, useMemo, useState } from 'react';
import { adminApi } from '../../api/adminApi';
import { useGame } from '../../store/GameContext';
import type { ChaseMatchInfo, ChasePhase, FreeroamAdminData, FreeroamSetting, FreeroamVehicle } from '../../types/admin';

const PHASE_LABELS: Record<ChasePhase, string> = {
  vote: 'Vote des véhicules',
  countdown: 'Départ',
  running: 'En course',
  pause: 'Fin de manche',
  ended: 'Terminée',
};

const ROLE_LABELS = { thief: 'VOLEUR', cop: 'POLICIER' };

/** Les courses en cours sont relues à ce rythme (ms) tant que l'onglet est ouvert */
const REFRESH_INTERVAL = 5000;

type Draft = FreeroamSetting['value'];

const copy = (setting: FreeroamSetting): Draft =>
  setting.kind === 'list' ? setting.value.map((vehicle) => ({ ...vehicle })) : setting.value;

/** Freeroam : courses poursuite en cours (mode spectateur) et véhicules des modes de jeu, enregistrés en base. */
export function FreeroamTab() {
  const { state, actions } = useGame();
  const [data, setData] = useState<FreeroamAdminData | null>(null);
  const [name, setName] = useState<string | null>(null);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [confirmReset, setConfirmReset] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async (keep?: string | null) => {
    const result = await adminApi.freeroam();
    if (!result?.ok) return actions.notify(result?.message ?? 'Réglages du Freeroam indisponibles.', 'error');
    setData(result);
    const selected = result.settings.find((setting) => setting.name === keep) ?? result.settings[0];
    setName(selected?.name ?? null);
    setDraft(selected ? copy(selected) : null);
  }, [actions]);

  /** Courses seulement : ne touche pas aux véhicules en cours de modification */
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

  const setting = data?.settings.find((entry) => entry.name === name) ?? null;
  const dirty = useMemo(() => Boolean(setting && draft !== null && JSON.stringify(copy(setting)) !== JSON.stringify(draft)), [setting, draft]);

  if (!data || !setting || draft === null) return <p className="muted">Chargement du Freeroam…</p>;

  const chases = Array.isArray(data.chases) ? data.chases : [];
  const spectating = state.admin.self.spectating;

  const select = (next: FreeroamSetting) => {
    setName(next.name);
    setDraft(copy(next));
    setConfirmReset(false);
  };
  const report = (result: { ok: boolean; message?: string } | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    return Boolean(result?.ok);
  };
  const save = async () => {
    setBusy(true);
    if (report(await adminApi.freeroamSave(setting.name, draft))) await load(setting.name);
    setBusy(false);
  };
  const reset = async () => {
    if (!confirmReset) return setConfirmReset(true);
    setConfirmReset(false);
    setBusy(true);
    if (report(await adminApi.freeroamReset(setting.name))) await load(setting.name);
    setBusy(false);
  };
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

      <span className="label admin-loot__section">Véhicules des modes de jeu</span>
      <nav className="admin-loot__tables">
        {data.settings.map((entry) => (
          <button
            key={entry.name}
            className={entry.name === setting.name ? 'admin-loot__table admin-loot__table--active' : 'admin-loot__table'}
            onClick={() => select(entry)}
          >
            <span className="disp">{entry.label}</span>
            {entry.modified && <span className="mono admin-loot__modified">MODIFIÉ</span>}
          </button>
        ))}
      </nav>
      <p className="muted admin-loot__used">{setting.hint}</p>

      {setting.kind === 'list' && Array.isArray(draft) ? (
        <VehicleList vehicles={draft} category={setting.category} onChange={setDraft} />
      ) : (
        <input
          className="admin-input mono"
          placeholder="Modèle (ex : granger)"
          value={typeof draft === 'string' ? draft : ''}
          aria-label="Modèle du véhicule"
          onChange={(event) => setDraft(event.target.value.trim().toLowerCase())}
        />
      )}

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
  const move = (index: number, offset: number) => {
    const next = [...vehicles];
    const [vehicle] = next.splice(index, 1);
    next.splice(index + offset, 0, vehicle);
    onChange(next);
  };
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
            <span className="admin-vehicles__buttons">
              <button className="btn btn--small" aria-label="Monter" disabled={index === 0} onClick={() => move(index, -1)}>↑</button>
              <button className="btn btn--small" aria-label="Descendre" disabled={index === vehicles.length - 1} onClick={() => move(index, 1)}>↓</button>
              <button
                className="btn btn--small btn--danger"
                aria-label="Retirer le véhicule"
                disabled={vehicles.length <= 1}
                onClick={() => onChange(vehicles.filter((_, i) => i !== index))}
              >
                ✕
              </button>
            </span>
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
