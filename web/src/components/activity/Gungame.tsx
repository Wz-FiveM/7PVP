import { useCallback, useEffect, useRef, useState } from 'react';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import type { GungameEndData, GungameHudData, GungameKillData, GungameStateData, GungameTopEntry } from '../../types/game';
import type { NuiMessage } from '../../types/nui';
import { EloDelta } from './EloDelta';
import './chase.css';
import './cvc.css';
import './gungame.css';

const END_TIME = 8000;
const TOAST_TIME = 2500;
const FEED_TIME = 5000;
const FEED_SIZE = 4;

const LEVEL_TOASTS = {
  kill: { title: 'Arme suivante', tone: 'good' },
  knifed: { title: 'Coup de couteau : tu recules', tone: 'bad' },
  suicide: { title: 'Suicide : tu recules', tone: 'bad' },
} as const;

interface Queue {
  count: number;
  needed: number;
  startIn?: number;
  at: number;
}

interface Toast {
  title: string;
  weapon: string;
  level: number;
  tone: 'good' | 'bad';
  id: number;
}

interface FeedEntry extends GungameKillData {
  id: number;
}

const formatTime = (seconds: number) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
const ordinal = (place: number) => (place === 1 ? '1er' : `${place}e`);

function useSecondsLeft(total: number, at: number): number {
  const [now, setNow] = useState(Date.now);
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 200);
    return () => window.clearInterval(timer);
  }, [at]);
  return Math.max(0, Math.ceil(total - (now - at) / 1000));
}

/** Gungame : file d'attente, HUD (arme, progression, rang, temps), classement, kills, hors zone, résultats. */
export function Gungame() {
  const [queue, setQueue] = useState<Queue | null>(null);
  const [hud, setHud] = useState<(GungameHudData & { at: number }) | null>(null);
  const [live, setLive] = useState<GungameStateData | null>(null);
  const [protection, setProtection] = useState<{ seconds: number; at: number } | null>(null);
  const [outside, setOutside] = useState(false);
  const [toast, setToast] = useState<Toast | null>(null);
  const [feed, setFeed] = useState<FeedEntry[]>([]);
  const [end, setEnd] = useState<(GungameEndData & { id: number }) | null>(null);
  /** Noms des armes, gardés pour les messages arrivés après la fermeture du HUD */
  const levels = useRef<string[]>([]);

  const handleMessage = useCallback((message: NuiMessage) => {
    switch (message.action) {
      case 'gungameQueue': {
        const { count, needed, startIn } = message.data;
        return setQueue(count > 0 ? { count, needed: needed ?? 2, startIn, at: Date.now() } : null);
      }
      case 'gungameHud': {
        const { open, ...data } = message.data;
        setLive(null);
        setOutside(false);
        setProtection(null);
        setFeed([]);
        if (!open || !data.levels) return setHud(null);
        levels.current = data.levels;
        return setHud({ ...(data as GungameHudData), at: Date.now() });
      }
      case 'gungameState':
        return setLive(message.data);
      case 'gungameLevel': {
        const { level, reason } = message.data;
        setHud((current) => (current ? { ...current, level } : current));
        const id = Date.now();
        setToast({ ...LEVEL_TOASTS[reason], weapon: levels.current[level - 1] ?? '', level, id });
        window.setTimeout(() => setToast((current) => (current?.id === id ? null : current)), TOAST_TIME);
        return;
      }
      case 'gungameSpawn':
        return setProtection(message.data.protection > 0 ? { seconds: message.data.protection, at: Date.now() } : null);
      case 'gungameKill': {
        const id = Date.now() + Math.random();
        setFeed((current) => [{ ...message.data, id }, ...current].slice(0, FEED_SIZE));
        window.setTimeout(() => setFeed((current) => current.filter((entry) => entry.id !== id)), FEED_TIME);
        return;
      }
      case 'gungameOutside':
        return setOutside(message.data.outside);
      case 'gungameEnd': {
        setHud(null);
        const id = Date.now();
        setEnd({ ...message.data, id });
        window.setTimeout(() => setEnd((current) => (current?.id === id ? null : current)), END_TIME);
        return;
      }
    }
  }, []);
  useNuiMessage(handleMessage);

  return (
    <>
      {queue && !hud && <GungameQueue queue={queue} />}
      {hud && <GungameHud hud={hud} live={live} protection={protection} />}
      {hud && live && <GungameTop top={live.top} />}
      {hud && feed.length > 0 && (
        <div className="gg-feed">
          {feed.map((entry) => (
            <div className="gg-feed__entry" key={entry.id}>
              {entry.killer ? (
                <>
                  <span className="gg-feed__name">{entry.killer}</span>
                  <span className={entry.knife ? 'mono gg-feed__how gg-feed__how--knife' : 'mono gg-feed__how'}>
                    {entry.knife ? 'COUTEAU' : 'KILL'}
                  </span>
                  <span className="gg-feed__name">{entry.victim}</span>
                </>
              ) : (
                <>
                  <span className="gg-feed__name">{entry.victim}</span>
                  <span className="mono gg-feed__how">SUICIDE</span>
                </>
              )}
            </div>
          ))}
        </div>
      )}
      {hud && toast && (
        <div className={`gg-toast gg-toast--${toast.tone}`} key={toast.id}>
          <span className="mono gg-toast__title">{toast.title}</span>
          <span className="disp gg-toast__weapon">
            {toast.level}. {toast.weapon}
          </span>
        </div>
      )}
      {hud && outside && (
        <div className="cvc-outside">
          <span className="disp">Hors zone</span>
          <span>Reviens dans la zone de combat : tu perds de la vie</span>
        </div>
      )}
      {end && (
        <div className={`chase-banner chase-banner--${end.result === 'won' ? 'good' : 'neutral'}`} key={end.id}>
          <span className="disp chase-banner__title">{end.result === 'won' ? 'Victoire' : `${ordinal(end.place)} place`}</span>
          <span className="chase-banner__text">{end.reason}</span>
          <span className="mono chase-banner__score">
            {ordinal(end.place).toUpperCase()} SUR {end.players} JOUEURS
          </span>
          {Array.isArray(end.top) && end.top.length > 0 && (
            <ol className="gg-results">
              {end.top.map((entry, index) => (
                <li className="gg-results__row" key={`${entry.name}-${index}`}>
                  <span className="mono gg-results__place">{index + 1}</span>
                  <span className="gg-results__name">{entry.name}</span>
                  <span className="mono gg-results__stat">NIV. {entry.level}</span>
                  <span className="mono gg-results__stat">{entry.kills} KILLS</span>
                </li>
              ))}
            </ol>
          )}
          {end.elo && <EloDelta elo={end.elo} />}
        </div>
      )}
    </>
  );
}

function GungameQueue({ queue }: { queue: Queue }) {
  const startIn = useSecondsLeft(queue.startIn ?? 0, queue.at);
  return (
    <div className="chase-queue">
      <span className="disp chase-queue__title">Gungame</span>
      <span className="mono chase-queue__text">
        {queue.startIn !== undefined
          ? `${queue.count} joueurs · départ dans ${startIn} s`
          : `En attente de joueurs · ${queue.count}/${queue.needed}`}
      </span>
    </div>
  );
}

function GungameHud({
  hud,
  live,
  protection,
}: {
  hud: GungameHudData & { at: number };
  live: GungameStateData | null;
  protection: { seconds: number; at: number } | null;
}) {
  const countdown = useSecondsLeft(hud.countdown, hud.at);
  const remainingAtStart = useSecondsLeft(hud.remaining, hud.at);
  const protectedFor = useSecondsLeft(protection?.seconds ?? 0, protection?.at ?? 0);
  const total = hud.levels.length;
  const weapon = hud.levels[hud.level - 1] ?? '';
  const next = hud.levels[hud.level];

  return (
    <>
      <div className="cvc-hud gg-hud">
        <div className="cvc-hud__top">
          <span className="disp cvc-hud__team">Gungame</span>
          {live && (
            <span className="mono cvc-hud__round">
              RANG {live.rank}/{live.players}
            </span>
          )}
          <span className="mono cvc-hud__time">{formatTime(live?.remaining ?? remainingAtStart)}</span>
        </div>
        <div className="gg-hud__weapon">
          <span className="disp gg-hud__level">
            {hud.level}
            <span className="gg-hud__total">/{total}</span>
          </span>
          <span className="gg-hud__names">
            <span className="disp gg-hud__current">{weapon}</span>
            <span className="mono gg-hud__next">{next ? `SUIVANTE : ${next.toUpperCase()}` : 'UN KILL POUR GAGNER'}</span>
          </span>
        </div>
        <div className="gg-hud__progress">
          {hud.levels.map((label, index) => (
            <span
              key={label}
              className={
                index + 1 < hud.level
                  ? 'gg-hud__step gg-hud__step--done'
                  : index + 1 === hud.level
                    ? 'gg-hud__step gg-hud__step--current'
                    : 'gg-hud__step'
              }
            />
          ))}
        </div>
        {live && (
          <div className="cvc-hud__alive">
            <span className="mono">KILLS : {live.kills}</span>
            <span className="mono">MORTS : {live.deaths}</span>
          </div>
        )}
        {protectedFor > 0 && countdown === 0 && <span className="mono gg-hud__shield">PROTÉGÉ · {protectedFor} S</span>}
      </div>
      {countdown > 0 && (
        <div className="chase-countdown" key={countdown}>
          <span className="disp">{countdown}</span>
        </div>
      )}
    </>
  );
}

function GungameTop({ top }: { top: GungameTopEntry[] }) {
  if (!Array.isArray(top) || top.length === 0) return null;
  return (
    <div className="gg-top">
      <span className="mono gg-top__title">CLASSEMENT</span>
      {top.map((entry, index) => (
        <div className="gg-top__row" key={`${entry.name}-${index}`}>
          <span className="mono gg-top__place">{index + 1}</span>
          <span className="gg-top__name">{entry.name}</span>
          <span className="mono gg-top__level">NIV. {entry.level}</span>
        </div>
      ))}
    </div>
  );
}
