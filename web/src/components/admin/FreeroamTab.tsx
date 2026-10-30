import { useCallback, useEffect, useMemo, useState } from 'react';
import { adminApi } from '../../api/adminApi';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type {
  ChaseMatchInfo,
  ChasePhase,
  FreeroamAdminData,
  FreeroamSetting,
  FreeroamVehicle,
} from '../../types/admin';

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

const copy = (setting: FreeroamSetting): FreeroamSetting => JSON.parse(JSON.stringify(setting));

/** Freeroam : courses poursuite en cours (mode spectateur) et véhicules des modes de jeu, enregistrés en base. */
export function FreeroamTab() {
  useT();
  const { state, actions } = useGame();
  const [data, setData] = useState<FreeroamAdminData | null>(null);

  const load = useCallback(async () => {
    const result = await adminApi.freeroam();
    if (!result?.ok) return actions.notify(result?.message ?? t('Réglages du Freeroam indisponibles.'), 'error');
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
  if (!data) return <p className="muted">{t('Chargement du Freeroam…')}</p>;

  const chases = Array.isArray(data.chases) ? data.chases : [];
  const spectating = state.admin.self.spectating;
  const spectate = async (target: number) => {
    if (await actions.adminAction({ action: 'spectate', target })) refreshChases();
  };

  return (
    <div className="admin-freeroam">
      <div className="admin-freeroam__head">
        <span className="label">{t('Courses poursuite en cours')}</span>
        <button className="btn btn--small" onClick={refreshChases}>{t('Actualiser')}</button>
      </div>
      {spectating && <SpectateBar name={spectating} onStop={() => actions.adminAction({ action: 'spectateStop' })} />}
      {chases.length > 0 ? (
        <ul className="admin-chases">
          {chases.map((match) => (
            <ChaseCard key={match.id} match={match} spectating={spectating} onSpectate={spectate} />
          ))}
        </ul>
      ) : (
        <p className="muted admin-empty">{t('Aucune course en cours.')}</p>
      )}
      <p className="muted admin-freeroam__queue">
        {data.chaseQueue > 0
          ? t("{count} joueur(s) dans la file d'attente.", { count: data.chaseQueue })
          : t("Personne dans la file d'attente.")}
        {' '}
        {t('Pour regarder un joueur hors course : onglet Joueurs, bouton « Regarder ».')}
      </p>

      <SettingsSection title={t('Véhicules des modes de jeu')} settings={settings.filter((s) => s.group === 'vehicles')} onSaved={load} />
    </div>
  );
}

/** Mode spectateur en cours : rappel des touches et arrêt. */
export function SpectateBar({ name, onStop }: { name: string; onStop: () => void }) {
  useT();
  return (
    <div className="admin-spectate">
      <span className="admin-spectate__text">
        <span className="disp">{t('Tu regardes {name}', { name })}</span>
        <span className="muted">{t('Retour arrière : quitter · ← → : autre joueur au même endroit')}</span>
      </span>
      <button className="btn btn--small btn--danger" onClick={onStop}>{t('Arrêter')}</button>
    </div>
  );
}

interface ChaseCardProps {
  match: ChaseMatchInfo;
  spectating: string | false;
  onSpectate: (target: number) => void;
}

function ChaseCard({ match, spectating, onSpectate }: ChaseCardProps) {
  useT();
  return (
    <li className="admin-chase">
      <header className="admin-chase__head">
        <span className="disp">{t('Course n°{id}', { id: match.id })}</span>
        <span className="mono muted">
          {match.round > 0 ? `${t('MANCHE {round}/2', { round: match.round })} · ` : ''}
          {t(PHASE_LABELS[match.phase]).toUpperCase()}
        </span>
      </header>
      {match.players.map((player) => (
        <div key={player.id} className="admin-chase__player">
          <span className="mono admin-player__id">{player.id}</span>
          <span className="admin-player__name">{player.name}</span>
          {player.role && (
            <span className={`mono admin-chase__role admin-chase__role--${player.role}`}>{t(ROLE_LABELS[player.role])}</span>
          )}
          <span className="mono muted" title={t('Manches gagnées · avertissements PIT')}>
            {t('{score} pt · {warns} PIT', { score: player.score, warns: player.warns })}
          </span>
          <button className="btn btn--small" disabled={spectating === player.name} onClick={() => onSpectate(player.id)}>
            {spectating === player.name ? t('Regardé') : t('Regarder')}
          </button>
        </div>
      ))}
    </li>
  );
}

// ---------------------------------------------------------------------------
// Réglages : un groupe de véhicules, un réglage affiché à la fois
// ---------------------------------------------------------------------------

interface SettingsSectionProps {
  title: string;
  settings: FreeroamSetting[];
  /** relit les réglages après un enregistrement */
  onSaved: () => Promise<void>;
}

function SettingsSection({ title, settings, onSaved }: SettingsSectionProps) {
  useT();
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
            {entry.modified && <span className="mono admin-loot__modified">{t('MODIFIÉ')}</span>}
          </button>
        ))}
      </nav>
      <p className="muted admin-loot__used">{setting.hint}</p>

      <SettingEditor draft={draft} onChange={setDraft} />

      <div className="admin-loot__actions">
        <button className="btn btn--small btn--primary" disabled={!dirty || busy} onClick={save}>
          {t('Enregistrer')}
        </button>
        <button className="btn btn--small" disabled={!dirty || busy} onClick={() => setDraft(copy(setting))}>
          {t('Annuler')}
        </button>
        <button className="btn btn--small btn--danger" disabled={busy} onClick={reset}>
          {confirmReset ? t('Confirmer : valeurs par défaut') : t('Valeurs par défaut')}
        </button>
      </div>
    </>
  );
}

function SettingEditor({ draft, onChange }: { draft: FreeroamSetting; onChange: (draft: FreeroamSetting) => void }) {
  useT();
  switch (draft.kind) {
    case 'vehicles':
      return <VehicleList vehicles={draft.value} category={draft.category} onChange={(value) => onChange({ ...draft, value })} />;
    case 'model':
      return (
        <input
          className="admin-input mono"
          placeholder={t('Modèle (ex : granger)')}
          value={draft.value}
          aria-label={t('Modèle du véhicule')}
          onChange={(event) => onChange({ ...draft, value: event.target.value.trim().toLowerCase() })}
        />
      );
    default:
      return null;
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
  useT();
  const categories = useMemo(() => [...new Set(vehicles.map((vehicle) => vehicle.category).filter(Boolean))], [vehicles]);
  const update = (index: number, patch: Partial<FreeroamVehicle>) =>
    onChange(vehicles.map((vehicle, i) => (i === index ? { ...vehicle, ...patch } : vehicle)));
  const rowClass = category ? 'admin-vehicles__row admin-vehicles__row--category' : 'admin-vehicles__row';

  return (
    <>
      <div className={`${rowClass} admin-vehicles__head mono`}>
        <span>{t('MODÈLE')}</span>
        <span>{t('NOM AFFICHÉ')}</span>
        {category && <span>{t('CATÉGORIE')}</span>}
        <span />
      </div>
      <ul className="admin-vehicles">
        {vehicles.map((vehicle, index) => (
          <li key={index} className={rowClass}>
            <input
              className="admin-input mono"
              value={vehicle.model}
              placeholder={t('ex : sultan')}
              aria-label={t('Modèle')}
              onChange={(event) => update(index, { model: event.target.value.trim().toLowerCase() })}
            />
            <input
              className="admin-input"
              value={vehicle.label}
              maxLength={40}
              aria-label={t('Nom affiché')}
              onChange={(event) => update(index, { label: event.target.value })}
            />
            {category && (
              <input
                className="admin-input"
                value={vehicle.category ?? ''}
                maxLength={40}
                list="admin-vehicle-categories"
                aria-label={t('Catégorie')}
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
        {t('+ Ajouter un véhicule')}
      </button>
    </>
  );
}

/** Monter, descendre, retirer (jamais le dernier : une liste ne peut pas être vide). */
export function RowButtons<T>({ index, list, onChange }: { index: number; list: T[]; onChange: (list: T[]) => void }) {
  useT();
  const move = (offset: number) => {
    const next = [...list];
    const [entry] = next.splice(index, 1);
    next.splice(index + offset, 0, entry);
    onChange(next);
  };
  return (
    <span className="admin-vehicles__buttons">
      <button className="btn btn--small" aria-label={t('Monter')} disabled={index === 0} onClick={() => move(-1)}>↑</button>
      <button className="btn btn--small" aria-label={t('Descendre')} disabled={index === list.length - 1} onClick={() => move(1)}>↓</button>
      <button
        className="btn btn--small btn--danger"
        aria-label={t('Retirer')}
        disabled={list.length <= 1}
        onClick={() => onChange(list.filter((_, i) => i !== index))}
      >
        ✕
      </button>
    </span>
  );
}
