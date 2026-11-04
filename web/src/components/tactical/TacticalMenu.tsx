import { useEffect, useState } from 'react';
import { gameApi } from '../../api/gameApi';
import { tacticalApi } from '../../api/tacticalApi';
import { useCountdown } from '../../hooks/useCountdown';
import { t } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { TacCatalog, TacLeaderboardRow, TacProfile, TacQueue, TacSlot } from '../../types/tactical';
import { AbilityIcon, RoleIcon } from './tacticalIcons';
import { DivisionChip, PlayerBanner, RoleBadge, SLOTS, findRole, money, slotKey } from './tacticalParts';

interface TacticalMenuProps {
  profile: TacProfile;
  catalog: TacCatalog;
  maps: number;
  queue: TacQueue | null;
  onProfile: (profile: TacProfile) => void;
}

type MenuTab = 'play' | 'roles' | 'board';

/** Emplacements de la file affichés autour du joueur (lui au centre) */
const BANNER_SLOTS = 5;

/** Menu du mode : file d'attente façon groupe, choix du rôle, classement. */
export function TacticalMenu({ profile, catalog, maps, queue, onProfile }: TacticalMenuProps) {
  const { actions } = useGame();
  const [tab, setTab] = useState<MenuTab>('play');
  const [busy, setBusy] = useState(false);

  const toggleQueue = async () => {
    if (busy) return;
    setBusy(true);
    const result = await tacticalApi.queue();
    setBusy(false);
    if (result && !result.ok && result.message) actions.notify(result.message, 'error');
  };

  const selectRole = async (role: string) => {
    if (role === profile.role) return;
    onProfile({ ...profile, role });
    const result = await tacticalApi.selectRole(role);
    if (result?.profile) onProfile(result.profile);
    if (result && !result.ok) {
      onProfile(profile);
      if (result.message) actions.notify(result.message, 'error');
    }
  };

  return (
    <div className={`tac-menu tac-menu--${tab}`}>
      <div className="tac-menu__veil" />
      <header className="tac-menu__bar">
        <button className="tac-menu__back" onClick={() => void gameApi.leaveToLobby()}>
          <span className="tac-menu__back-arrow">‹</span>
          <span className="label">{t('Retour')}</span>
          <span className="tac-menu__crumb disp">// {t('Sabotage')}</span>
        </button>
        <nav className="tac-menu__tabs">
          <MenuTabButton id="roles" tab={tab} onSelect={setTab}>{t('Rôles')}</MenuTabButton>
          <MenuTabButton id="play" tab={tab} onSelect={setTab} main>{t('Jouer')}</MenuTabButton>
          <MenuTabButton id="board" tab={tab} onSelect={setTab}>{t('Classement')}</MenuTabButton>
        </nav>
        <div className="tac-menu__me">
          <span className="tac-menu__me-name">{profile.name}</span>
          <DivisionChip catalog={catalog} division={profile.division} rating={profile.rating} />
        </div>
      </header>

      {tab === 'play' && (
        <PlayView profile={profile} catalog={catalog} maps={maps} queue={queue} busy={busy} onToggle={() => void toggleQueue()} onRoles={() => setTab('roles')} />
      )}
      {tab === 'roles' && <RolesView profile={profile} catalog={catalog} onSelect={(role) => void selectRole(role)} onDone={() => setTab('play')} />}
      {tab === 'board' && <BoardView profile={profile} catalog={catalog} />}
    </div>
  );
}

function MenuTabButton({ id, tab, onSelect, main, children }: { id: MenuTab; tab: MenuTab; onSelect: (tab: MenuTab) => void; main?: boolean; children: string }) {
  return (
    <button className={`tac-menu__tab ${main ? 'tac-menu__tab--main' : ''} ${tab === id ? 'tac-menu__tab--on' : ''}`} onClick={() => onSelect(id)}>
      {children}
    </button>
  );
}

/* Jouer ------------------------------------------------------------------- */

interface PlayViewProps {
  profile: TacProfile;
  catalog: TacCatalog;
  maps: number;
  queue: TacQueue | null;
  busy: boolean;
  onToggle: () => void;
  onRoles: () => void;
}

function PlayView({ profile, catalog, maps, queue, busy, onToggle, onRoles }: PlayViewProps) {
  const startIn = useCountdown(queue && queue.startIn !== false ? queue.startIn : 0, queue);
  const searching = useElapsed(queue !== null);
  const ratio = profile.deaths > 0 ? profile.kills / profile.deaths : profile.kills;
  const winRate = profile.matches > 0 ? Math.round((profile.wins / profile.matches) * 100) : 0;

  // Les autres joueurs de la file, de part et d'autre du joueur
  const others = (queue?.players ?? (queue?.names ?? []).map((name) => ({ name, role: '', rating: 0, division: '' })))
    .filter((player) => player.name !== profile.name);
  const shown = others.slice(0, BANNER_SLOTS - 1);
  const center = Math.floor(BANNER_SLOTS / 2);
  // index dans `shown` par emplacement (les plus proches du joueur d'abord), -1 = le joueur
  const order = [2, 0, -1, 1, 3];
  const extra = others.length - shown.length;

  return (
    <div className="tac-play">
      <div className="tac-play__status">
        {queue ? (
          <>
            <span className="disp mono tac-play__clock">{queue.startIn === false ? searching : `0:${String(startIn).padStart(2, '0')}`}</span>
            <span className="label">
              {queue.startIn === false
                ? t('En attente de joueurs ({needed} pour lancer)', { needed: queue.needed })
                : t('Lancement dans {seconds} s', { seconds: startIn })}
            </span>
          </>
        ) : (
          <span className="label">{t('Deux équipes, une seule vie par manche. Premier à {rounds} manches.', { rounds: catalog.roundsToWin })}</span>
        )}
      </div>

      <aside className="tac-play__info">
        <InfoLine label={t('File')} value={t('Classée')} />
        <InfoLine label={t('Joueurs')} value={queue ? `${queue.count} / ${queue.max}` : t('{min} à {max}', { min: 4, max: 10 })} />
        <InfoLine label={t('Cartes')} value={String(maps)} />
        <div className="tac-play__stats">
          <Stat label={t('Parties')} value={profile.matches} />
          <Stat label={t('Victoires')} value={`${winRate} %`} />
          <Stat label="K/D" value={ratio.toFixed(2)} />
          <Stat label="MVP" value={profile.mvps} />
        </div>
      </aside>

      <div className="tac-play__banners">
        {Array.from({ length: BANNER_SLOTS }, (_, slot) => {
          const index = order[slot];
          if (slot === center || index === -1) {
            return (
              <PlayerBanner
                key="me"
                catalog={catalog}
                name={profile.name}
                role={profile.role}
                division={profile.division}
                rating={profile.rating}
                me
                status={queue ? t('En file') : t('Prêt')}
              />
            );
          }
          const player = shown[index];
          return player ? (
            <PlayerBanner
              key={`${player.name}-${slot}`}
              catalog={catalog}
              name={player.name}
              role={player.role || undefined}
              division={player.division || undefined}
              rating={player.rating || undefined}
              status={t('En file')}
            />
          ) : (
            <PlayerBanner key={`empty-${slot}`} catalog={catalog} empty status={queue ? t('Recherche…') : ''} />
          );
        })}
      </div>
      {extra > 0 && <span className="tac-play__extra mono">+{extra}</span>}

      <footer className="tac-play__actions">
        <button className="tac-play__side-button" onClick={onRoles}>
          <RoleIcon id={profile.role} className="tac-play__side-icon" />
          {t('Changer de rôle')}
        </button>
        <button className={`tac-play__start ${queue ? 'tac-play__start--on' : ''}`} disabled={busy || (!queue && maps === 0)} onClick={onToggle}>
          {queue ? t('Annuler') : t('Lancer')}
        </button>
        <button className="tac-play__side-button" onClick={() => void gameApi.leaveToLobby()}>{t('Retour au lobby')}</button>
      </footer>
      {!queue && maps === 0 && <p className="tac-play__warning">{t('Aucune carte disponible pour le moment.')}</p>}
    </div>
  );
}

/** Temps passé en file, en m:ss */
function useElapsed(active: boolean): string {
  const [start, setStart] = useState<number | null>(null);
  const [, setTick] = useState(0);
  useEffect(() => {
    if (!active) return setStart(null);
    setStart(Date.now());
    const timer = window.setInterval(() => setTick((value) => value + 1), 1000);
    return () => window.clearInterval(timer);
  }, [active]);
  const seconds = start ? Math.floor((Date.now() - start) / 1000) : 0;
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}

function InfoLine({ label, value }: { label: string; value: string }) {
  return (
    <div className="tac-play__line">
      <span className="label">{label}</span>
      <strong className="disp">{value}</strong>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="tac-stat">
      <span className="disp tac-stat__value">{value}</span>
      <span className="label">{label}</span>
    </div>
  );
}

/* Rôles ------------------------------------------------------------------- */

type RoleTab = 'info' | TacSlot;

function RolesView({ profile, catalog, onSelect, onDone }: { profile: TacProfile; catalog: TacCatalog; onSelect: (role: string) => void; onDone: () => void }) {
  const [viewed, setViewed] = useState(profile.role);
  const [section, setSection] = useState<RoleTab>('info');
  const role = findRole(catalog, viewed);
  if (!role) return null;
  const chosen = role.id === profile.role;
  const ability = section === 'info' ? null : role.abilities[section];

  return (
    <div className={`tac-roles-view tac-role--${role.id}`}>
      <div className="tac-roles-view__ghost disp" aria-hidden>
        {Array.from({ length: 4 }, (_, index) => <span key={index}>{t(role.label)}</span>)}
      </div>

      <div className="tac-roles-view__emblem">
        <RoleBadge role={role} size="xl" />
      </div>

      <section className="tac-roles-view__detail">
        <span className="label tac-roles-view__kind">{t('Rôle')}</span>
        <h2 className="disp tac-roles-view__name">{t(role.label)}</h2>
        <div className="tac-roles-view__tabs">
          <button className={`tac-roles-view__tab ${section === 'info' ? 'tac-roles-view__tab--on' : ''}`} onClick={() => setSection('info')}>
            <span className="tac-roles-view__tab-key">Info</span>
            <span className="tac-roles-view__tab-icon tac-roles-view__tab-icon--text">i</span>
          </button>
          {SLOTS.map((slot) => (
            <button key={slot} className={`tac-roles-view__tab ${section === slot ? 'tac-roles-view__tab--on' : ''}`} onClick={() => setSection(slot)}>
              <span className="tac-roles-view__tab-key">{slotKey(catalog, slot)}</span>
              <AbilityIcon id={role.abilities[slot].id} className="tac-roles-view__tab-icon" />
            </button>
          ))}
        </div>
        {ability ? (
          <div className="tac-roles-view__text">
            <h3 className="disp">{t(ability.label)}</h3>
            <p>{t(ability.description)}</p>
            <span className="mono tac-roles-view__cost">
              {section === 'x'
                ? t('Ultime · {points} points', { points: ability.cost ?? 0 })
                : ability.free
                  ? t('Offerte à chaque manche')
                  : t('{price} la charge · {max} au plus', { price: money(ability.price ?? 0), max: ability.max ?? 1 })}
            </span>
          </div>
        ) : (
          <div className="tac-roles-view__text">
            <p className="tac-roles-view__lead">{t(role.description)}</p>
            <ul className="tac-roles-view__list">
              {SLOTS.map((slot) => (
                <li key={slot}>
                  <span className="keycap">{slotKey(catalog, slot)}</span>
                  <strong>{t(role.abilities[slot].label)}</strong>
                </li>
              ))}
            </ul>
          </div>
        )}
      </section>

      <footer className="tac-roles-view__foot">
        <div className="tac-roles-view__actions">
          <button className="tac-play__start tac-roles-view__choose" disabled={chosen} onClick={() => onSelect(role.id)}>
            {chosen ? t('Rôle choisi') : t('Choisir ce rôle')}
          </button>
          <button className="tac-play__side-button" onClick={onDone}>{t('Jouer')}</button>
        </div>
        <div className="tac-roles-view__picker">
          {catalog.roles.map((entry) => (
            <button
              key={entry.id}
              className={`tac-role-tile tac-role--${entry.id} ${entry.id === viewed ? 'tac-role-tile--viewed' : ''} ${entry.id === profile.role ? 'tac-role-tile--chosen' : ''}`}
              onClick={() => {
                setViewed(entry.id);
                setSection('info');
              }}
            >
              <RoleIcon id={entry.id} className="tac-role-tile__icon" />
              <span className="tac-role-tile__name">{t(entry.label)}</span>
            </button>
          ))}
        </div>
      </footer>
    </div>
  );
}

/* Classement -------------------------------------------------------------- */

function BoardView({ profile, catalog }: { profile: TacProfile; catalog: TacCatalog }) {
  const [rows, setRows] = useState<TacLeaderboardRow[] | null>(null);
  useEffect(() => {
    void tacticalApi.leaderboard().then((result) => setRows(result?.rows ?? []));
  }, []);

  return (
    <div className="tac-board-view">
      <div className="tac-card tac-board">
        {!rows && <p className="muted">{t('Chargement…')}</p>}
        {rows && rows.length === 0 && <p className="muted">{t('Personne n\'a encore joué de partie classée.')}</p>}
        {rows && rows.length > 0 && (
          <table className="tac-table">
            <thead>
              <tr>
                <th>#</th>
                <th>{t('Joueur')}</th>
                <th>{t('Division')}</th>
                <th>{t('Cote')}</th>
                <th>{t('Victoires')}</th>
                <th>K/D</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, index) => (
                <tr key={`${row.name}-${index}`} className={row.name === profile.name ? 'tac-table__me' : ''}>
                  <td className="mono">{index + 1}</td>
                  <td>{row.name}</td>
                  <td><DivisionChip catalog={catalog} division={row.division} /></td>
                  <td className="mono">{row.rating}</td>
                  <td className="mono">{row.wins}/{row.matches}</td>
                  <td className="mono">{(row.deaths > 0 ? row.kills / row.deaths : row.kills).toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
