import { useCallback, useState } from 'react';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type {
  CodBoardEntry, CodCatalog, CodDeadData, CodHudData, CodHudState, CodKillData, CodObjective, CodRoundEndData, CodStateData, CodStreakState, CodTeamId,
} from '../../types/cod';
import type { NuiMessage } from '../../types/nui';
import { WeaponSilhouette } from '../hud/Killfeed';
import { Icon } from '../icons/Icon';
import { formatTime, RankBadge, useSecondsLeft } from './CodParts';
import { CodStreakIcon } from './CodStreakIcon';
import { CodTabletScreen, type CodTabletView } from './CodTabletScreen';

const FEED_TIME = 5000;
const FEED_SIZE = 5;
const SCORE_TIME = 1800;
const SCORE_SIZE = 4;
const NOTICE_TIME = 3500;
const BANNER_TIME = 5000;

interface Timed {
  id: number;
}

interface CodHudProps {
  hud: CodHudState | null;
  live: CodStateData | null;
  catalog: CodCatalog | null;
  rank: number;
  name: string;
}

/** HUD de partie, épuré : vie sous la carte, emblème et score en bas à gauche, munitions en bas à droite. */
export function CodHud({ hud, live, catalog, rank, name }: CodHudProps) {
  useT();
  const [feed, setFeed] = useState<(CodKillData & Timed)[]>([]);
  const [scores, setScores] = useState<({ xp: number; label: string } & Timed)[]>([]);
  const [streak, setStreak] = useState<CodStreakState | null>(null);
  const [notice, setNotice] = useState<({ text: string; friendly?: boolean } & Timed) | null>(null);
  const [dead, setDead] = useState<(CodDeadData & { at: number }) | null>(null);
  const [protection, setProtection] = useState<{ seconds: number; at: number } | null>(null);
  const [outside, setOutside] = useState(false);
  const [scoreboard, setScoreboard] = useState(false);
  const [action, setAction] = useState<{ kind: string; seconds: number; at: number } | null>(null);
  const [banner, setBanner] = useState<(CodRoundEndData & Timed) | null>(null);
  const [roundCountdown, setRoundCountdown] = useState<{ seconds: number; at: number } | null>(null);
  const [nuke, setNuke] = useState<{ seconds: number; at: number } | null>(null);
  const [jammed, setJammed] = useState(false);
  const [tablet, setTablet] = useState<CodTabletView | null>(null);

  const showNotice = useCallback((text: string, friendly?: boolean) => {
    const id = Date.now() + Math.random();
    setNotice({ text, friendly, id });
    window.setTimeout(() => setNotice((current) => (current?.id === id ? null : current)), NOTICE_TIME);
  }, []);

  const handleMessage = useCallback((message: NuiMessage) => {
    switch (message.action) {
      case 'codHud':
        setFeed([]);
        setScores([]);
        setDead(null);
        setOutside(false);
        setScoreboard(false);
        setAction(null);
        setBanner(null);
        setNuke(null);
        setJammed(false);
        setProtection(null);
        setRoundCountdown(null);
        setTablet(null);
        if (!message.data.open || !message.data.playlist) setStreak(null);
        return;
      case 'codKill': {
        const id = Date.now() + Math.random();
        setFeed((current) => [...current, { ...message.data, id }].slice(-FEED_SIZE));
        window.setTimeout(() => setFeed((current) => current.filter((entry) => entry.id !== id)), FEED_TIME);
        return;
      }
      case 'codScore': {
        const id = Date.now() + Math.random();
        setScores((current) => [{ ...message.data, id }, ...current].slice(0, SCORE_SIZE));
        window.setTimeout(() => setScores((current) => current.filter((entry) => entry.id !== id)), SCORE_TIME);
        return;
      }
      case 'codStreak':
        return setStreak(message.data);
      case 'codStreakEarned':
        return showNotice(t('Série disponible : {label}', { label: t(message.data.label) }), true);
      case 'codNotice':
        return showNotice(message.data.text, message.data.friendly);
      case 'codDead':
        return setDead({ ...message.data, at: Date.now() });
      case 'codSpawn':
        setDead(null);
        return setProtection(message.data.protection > 0 ? { seconds: message.data.protection, at: Date.now() } : null);
      case 'codOutside':
        return setOutside(message.data.outside);
      case 'codScoreboard':
        return setScoreboard(message.data.open);
      case 'codAction':
        return setAction(message.data.kind ? { kind: message.data.kind, seconds: message.data.seconds ?? 0, at: Date.now() } : null);
      case 'codRoundEnd': {
        const id = Date.now();
        setBanner({ ...message.data, id });
        window.setTimeout(() => setBanner((current) => (current?.id === id ? null : current)), BANNER_TIME);
        return;
      }
      case 'codRoundStart':
        return setRoundCountdown({ seconds: message.data.countdown, at: Date.now() });
      case 'codNuke':
        return setNuke({ seconds: message.data.seconds, at: Date.now() });
      case 'codJam':
        return setJammed(message.data.active);
      case 'codTablet': {
        const { state, seconds, title, help } = message.data;
        // Le titre et l'aide ne sont envoyés qu'à l'ouverture
        return setTablet((current) => (state
          ? { state, seconds: seconds ?? 0, title: title ?? current?.title ?? '', help: help ?? current?.help ?? [] }
          : null));
      }
    }
  }, [showNotice]);
  useNuiMessage(handleMessage);

  if (!hud) return null;
  const flying = tablet?.state === 'flying' || tablet?.state === 'lost';
  return (
    <>
      {!flying && (
        <>
          {!jammed && <RadarFilter />}
          <Vitals name={name} />
          <BottomLeft hud={hud} live={live} rank={rank} />
          <BottomRight streak={streak} keys={catalog?.keys} />
          <TopCenter hud={hud} live={live} />
        </>
      )}
      {tablet && <CodTabletScreen view={tablet} />}

      {feed.length > 0 && (
        <div className="cod-feed">
          {feed.map((entry) => <FeedRow key={entry.id} entry={entry} team={hud.team} />)}
        </div>
      )}
      {scores.length > 0 && (
        <div className="cod-scores">
          {scores.map((entry) => (
            <div className="cod-scores__row" key={entry.id}>
              <span className="cod-scores__xp">+{entry.xp}</span>
              <span>{entry.label}</span>
            </div>
          ))}
        </div>
      )}
      {notice && (
        <div className={notice.friendly === false ? 'cod-notice cod-notice--enemy' : 'cod-notice'} key={notice.id}>{notice.text}</div>
      )}

      <Countdown hud={hud} round={roundCountdown} />
      {protection && <Protection protection={protection} />}
      {dead && <DeadBar dead={dead} />}
      {action && <ActionBar action={action} />}
      {nuke && <NukeCounter nuke={nuke} />}
      {jammed && <div className="cod-jam">{t('CARTE BROUILLÉE')}</div>}
      {outside && (
        <div className="cod-outside">
          <span className="cod-outside__title">{t('Retourne au combat')}</span>
          <span>{t('Hors de la zone : tu perds de la vie')}</span>
        </div>
      )}
      {banner && (
        <div className={`cod-banner cod-banner--${banner.result}`} key={banner.id}>
          <h2 className="cod-banner__title">{banner.result === 'won' ? t('Manche gagnée') : t('Manche perdue')}</h2>
          <span>{banner.reason}</span>
        </div>
      )}
      {scoreboard && live && (
        <div className="cod-board">
          <header className="cod-board__head">
            <span className="cod-board__title">{t(hud.playlist.label)}</span>
            <span className="cod-label">{t(hud.map.label)}</span>
          </header>
          <CodScoreTable board={live.board} team={hud.team} teams={hud.teams} scores={live.scores} />
        </div>
      )}
    </>
  );
}

/** Filtre de vieux téléviseur, posé exactement sur la carte du jeu. */
function RadarFilter() {
  const { minimap } = useGame().state;
  if (!minimap?.visible) return null;
  return (
    <div
      className="cod-crt"
      style={{
        left: `${minimap.left * 100}%`,
        top: `${minimap.top * 100}%`,
        width: `${(minimap.right - minimap.left) * 100}%`,
        height: `${(minimap.bottom - minimap.top) * 100}%`,
      }}
    />
  );
}

/** Pseudo et barre de vie, juste sous la carte. */
function Vitals({ name }: { name: string }) {
  const { state } = useGame();
  const vitals = state.vitals;
  const health = vitals.maxHealth > 0 ? (vitals.health / vitals.maxHealth) * 100 : 0;
  return (
    <div className="cod-vitals">
      <span className="cod-vitals__name">{name}</span>
      <span className="cod-vitals__row">
        <span className={health < 30 ? 'cod-vitals__bar cod-vitals__bar--low' : 'cod-vitals__bar'}>
          <span style={{ width: `${health}%` }} />
        </span>
        <span className="cod-vitals__value">{Math.round(vitals.health)}</span>
      </span>
      {vitals.armor > 0 && (
        <span className="cod-vitals__bar cod-vitals__bar--armor">
          <span style={{ width: `${vitals.armor}%` }} />
        </span>
      )}
    </div>
  );
}

function BottomLeft({ hud, live, rank }: { hud: CodHudData & { at: number }; live: CodStateData | null; rank: number }) {
  useT();
  const remainingAtStart = useSecondsLeft(hud.remaining, hud.at);
  const remaining = live?.remaining ?? remainingAtStart;
  const me = live?.board.find((entry) => entry.id === hud.self);
  const leader = live?.board[0];
  const team = hud.team;
  const them: CodTeamId = team === 'alpha' ? 'bravo' : 'alpha';
  const limit = hud.playlist.scoreLimit;
  const ours = team ? (live?.scores[team] ?? 0) : (me?.kills ?? 0);
  const theirs = team ? (live?.scores[them] ?? 0) : (leader && leader.id !== hud.self ? leader.kills : (live?.board[1]?.kills ?? 0));

  return (
    <div className="cod-corner">
      <span className="cod-corner__mode">{hud.playlist.short}</span>
      <div className="cod-corner__row">
        <RankBadge rank={rank} size={54} />
        <div className="cod-corner__scores">
          <ScoreLine value={ours} limit={limit} tone="us" />
          <ScoreLine value={theirs} limit={limit} tone="them" />
          <span className="cod-corner__time">{formatTime(remaining)}</span>
        </div>
      </div>
      <span className="cod-corner__map">{t(hud.map.label).toUpperCase()} · {me ? `${me.kills} / ${me.deaths}` : '0 / 0'}</span>
    </div>
  );
}

function ScoreLine({ value, limit, tone }: { value: number; limit: number; tone: 'us' | 'them' }) {
  return (
    <span className={`cod-line cod-line--${tone}`}>
      <span className="cod-line__value">{value}</span>
      <span className="cod-line__track"><span style={{ width: `${Math.min(100, (value / Math.max(limit, 1)) * 100)}%` }} /></span>
    </span>
  );
}

function BottomRight({ streak, keys }: { streak: CodStreakState | null; keys?: CodCatalog['keys'] }) {
  useT();
  const { state } = useGame();
  const vitals = state.vitals;
  const hasAmmo = vitals.weapon && vitals.clip + vitals.reserve > 0;
  return (
    <div className="cod-ammo">
      {streak && <StreakSlots streak={streak} keyLabel={keys?.streak ?? 'G'} />}
      {hasAmmo && (
        <div className="cod-ammo__count">
          <span className="cod-ammo__clip">{vitals.clip}</span>
          <span className="cod-ammo__reserve">{vitals.reserve}</span>
        </div>
      )}
    </div>
  );
}

/** Une case par série choisie, de la plus chère en haut à la moins chère en bas : allumée quand elle est disponible. */
function StreakSlots({ streak, keyLabel }: { streak: CodStreakState; keyLabel: string }) {
  useT();
  const { items, slots } = streak;
  const last = items[items.length - 1];
  // Une série sortie d'un colis n'est pas forcément parmi les séries choisies : elle prend une case de plus
  const extras = items.filter((item, index) =>
    !slots.some((slot) => slot.id === item.id) && items.findIndex((other) => other.id === item.id) === index);
  const list = [...extras.map((item) => ({ ...item, kills: 0 })), ...[...slots].reverse()];
  return (
    <div className="cod-streaks">
      {list.map((slot) => {
        const count = items.filter((item) => item.id === slot.id).length;
        const counting = count === 0 && streak.streak < slot.kills;
        return (
          <div className="cod-streaks__row" key={slot.id}>
            {slot.id === last?.id && (
              <span className="cod-ammo__ready">
                <span className="cod-key">{keyLabel}</span>
                {t(slot.label)}
              </span>
            )}
            <span className={count > 0 ? 'cod-streak cod-streak--ready' : 'cod-streak'}>
              <CodStreakIcon id={slot.id} />
              {count > 1 && <span className="cod-streak__count">×{count}</span>}
              {count === 0 && (
                <span className="cod-streak__kills">{counting && streak.streak > 0 ? `${streak.streak}/${slot.kills}` : slot.kills}</span>
              )}
              {counting && <span className="cod-streak__bar" style={{ width: `${(streak.streak / slot.kills) * 100}%` }} />}
            </span>
          </div>
        );
      })}
    </div>
  );
}

function TopCenter({ hud, live }: { hud: CodHudData; live: CodStateData | null }) {
  useT();
  const objective = live?.objective;
  if (!objective) return null;
  return (
    <div className="cod-objective">
      {objective.kind === 'flags' && objective.flags.map((flag) => (
        <FlagChip key={flag.id} flag={flag} team={hud.team} />
      ))}
      {objective.kind === 'sites' && <BombStatus objective={objective} team={hud.team} />}
    </div>
  );
}

function FlagChip({ flag, team }: { flag: Extract<CodObjective, { kind: 'flags' }>['flags'][number]; team: CodTeamId | false }) {
  const tone = !flag.owner ? '' : flag.owner === team ? 'cod-flag--friend' : 'cod-flag--enemy';
  const capturing = flag.capturing ? (flag.capturing === team ? 'cod-flag__fill--friend' : 'cod-flag__fill--enemy') : '';
  return (
    <span className={`cod-flag ${tone}`}>
      <span className={`cod-flag__fill ${capturing}`} style={{ height: `${flag.progress * 100}%` }} />
      <span className="cod-flag__letter">{flag.id}</span>
    </span>
  );
}

function BombStatus({ objective, team }: { objective: Extract<CodObjective, { kind: 'sites' }>; team: CodTeamId | false }) {
  useT();
  const attacking = objective.attackers === team;
  return (
    <span className="cod-bomb">
      <span className="cod-label">{t('MANCHE {round}', { round: objective.round })} · {attacking ? t('ATTAQUE') : t('DÉFENSE')}</span>
      {objective.bomb && (
        <span className="cod-bomb__timer">{t('BOMBE SITE {site} · {seconds} S', { site: objective.bomb.site, seconds: objective.bomb.remaining })}</span>
      )}
    </span>
  );
}

function FeedRow({ entry, team }: { entry: CodKillData & Timed; team: CodTeamId | false }) {
  const tone = (side?: CodTeamId | false) => (team && side === team ? 'cod-feed__name--friend' : 'cod-feed__name--enemy');
  return (
    <div className="cod-feed__row">
      {entry.killer && <span className={`cod-feed__name ${tone(entry.killerTeam)}`}>{entry.killer}</span>}
      <span className="cod-feed__how">
        {entry.weapon ? <WeaponSilhouette weapon={entry.weapon.toLowerCase()} /> : <CodStreakIcon id={entry.streak ?? 'skull'} />}
        {entry.headshot && <Icon name="crosshair" size={14} strokeWidth={2.2} />}
      </span>
      <span className={`cod-feed__name ${tone(entry.victimTeam)}`}>{entry.victim}</span>
    </div>
  );
}

function Countdown({ hud, round }: { hud: CodHudData & { at: number }; round: { seconds: number; at: number } | null }) {
  const first = useSecondsLeft(hud.countdown, hud.at);
  const next = useSecondsLeft(round?.seconds ?? 0, round?.at ?? 0);
  const value = Math.max(first, next);
  if (value <= 0) return null;
  return <div className="cod-countdown" key={value}>{value}</div>;
}

function Protection({ protection }: { protection: { seconds: number; at: number } }) {
  useT();
  const seconds = useSecondsLeft(protection.seconds, protection.at);
  if (seconds <= 0) return null;
  return <div className="cod-shield">{t('PROTÉGÉ · {seconds} S', { seconds })}</div>;
}

function DeadBar({ dead }: { dead: CodDeadData & { at: number } }) {
  useT();
  const seconds = useSecondsLeft(dead.respawn || 0, dead.at);
  return (
    <div className="cod-dead">
      <span className="cod-dead__title">{dead.killer ? t('Tué par {name}', { name: dead.killer }) : t('Tu es mort')}</span>
      {dead.weapon && <span className="cod-label">{t(dead.weapon)}</span>}
      <span className="cod-dead__next">
        {dead.respawn === false ? t('Prochaine manche bientôt') : t('Réapparition dans {seconds} s', { seconds })}
      </span>
    </div>
  );
}

function ActionBar({ action }: { action: { kind: string; seconds: number; at: number } }) {
  useT();
  const labels: Record<string, string> = { plant: t('Pose de la bombe'), defuse: t('Désamorçage'), crate: t('Ouverture du colis') };
  return (
    <div className="cod-action-bar">
      <span className="cod-label">{labels[action.kind]}</span>
      <span className="cod-xpbar">
        <span className="cod-action-bar__fill" style={{ animationDuration: `${action.seconds}s` }} />
      </span>
    </div>
  );
}

function NukeCounter({ nuke }: { nuke: { seconds: number; at: number } }) {
  useT();
  const seconds = useSecondsLeft(nuke.seconds, nuke.at);
  return <div className="cod-nuke">{t('FRAPPE NUCLÉAIRE · {seconds}', { seconds })}</div>;
}

interface CodScoreTableProps {
  board: CodBoardEntry[];
  team: CodTeamId | false;
  teams?: { id: CodTeamId; label: string }[];
  scores?: Record<CodTeamId, number>;
}

/** Tableau des scores : notre équipe d'abord, ou tous les joueurs en chacun pour soi. */
export function CodScoreTable({ board, team, teams, scores }: CodScoreTableProps) {
  useT();
  const rows = (list: CodBoardEntry[]) =>
    list.map((entry, index) => (
      <tr key={entry.id} className={entry.alive ? '' : 'cod-table__dead'}>
        <td>{index + 1}</td>
        <td className="cod-table__name">{entry.name}</td>
        <td>{entry.score}</td>
        <td>{entry.kills}</td>
        <td>{entry.deaths}</td>
        <td>{entry.assists}</td>
      </tr>
    ));
  const head = (
    <thead>
      <tr>
        <th>#</th>
        <th className="cod-table__name">{t('Joueur')}</th>
        <th>{t('Score')}</th>
        <th>{t('Kills')}</th>
        <th>{t('Morts')}</th>
        <th>{t('Assist.')}</th>
      </tr>
    </thead>
  );

  if (!team) return <table className="cod-table">{head}<tbody>{rows(board)}</tbody></table>;

  const them: CodTeamId = team === 'alpha' ? 'bravo' : 'alpha';
  const label = (id: CodTeamId) => {
    const entry = teams?.find((candidate) => candidate.id === id);
    return entry ? t(entry.label) : '';
  };
  return (
    <div className="cod-table__teams">
      {[team, them].map((id) => (
        <div key={id} className={id === team ? 'cod-table__team cod-table__team--us' : 'cod-table__team'}>
          {teams && (
            <div className="cod-table__team-head">
              <span>{label(id)}</span>
              {scores && <span>{scores[id]}</span>}
            </div>
          )}
          <table className="cod-table">{head}<tbody>{rows(board.filter((entry) => entry.team === id))}</tbody></table>
        </div>
      ))}
    </div>
  );
}
