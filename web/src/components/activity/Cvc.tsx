import { useCallback, useEffect, useState } from 'react';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import type { CvcHudData, CvcScores, CvcStateData } from '../../types/game';
import type { NuiMessage } from '../../types/nui';
import './chase.css';
import './cvc.css';

const RESULT_TITLES = {
  round: { won: 'Manche gagnée', lost: 'Manche perdue', draw: 'Manche nulle' },
  match: { won: 'Victoire', lost: 'Défaite', draw: 'Égalité' },
};
const TONES = { won: 'good', lost: 'bad', draw: 'neutral' } as const;
const BANNER_TIME = 5000;

interface Queue {
  count: number;
  needed: number;
  startIn?: number;
  at: number;
}

interface Banner {
  title: string;
  text?: string;
  scores: CvcScores;
  tone: 'good' | 'bad' | 'neutral';
  id: number;
}

const formatTime = (seconds: number) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

function useSecondsLeft(total: number, at: number): number {
  const [now, setNow] = useState(Date.now);
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 200);
    return () => window.clearInterval(timer);
  }, [at]);
  return Math.max(0, Math.ceil(total - (now - at) / 1000));
}

/** CVC : file d'attente, HUD de manche (équipe, score, survivants), hors zone, résultats. */
export function Cvc() {
  const [queue, setQueue] = useState<Queue | null>(null);
  const [hud, setHud] = useState<(CvcHudData & { at: number }) | null>(null);
  const [live, setLive] = useState<CvcStateData | null>(null);
  const [outside, setOutside] = useState(false);
  const [banner, setBanner] = useState<Banner | null>(null);

  const showBanner = useCallback((next: Omit<Banner, 'id'>) => {
    const id = Date.now();
    setBanner({ ...next, id });
    window.setTimeout(() => setBanner((current) => (current?.id === id ? null : current)), BANNER_TIME);
  }, []);

  const handleMessage = useCallback(
    (message: NuiMessage) => {
      switch (message.action) {
        case 'cvcQueue': {
          const { count, needed, startIn } = message.data;
          return setQueue(count > 0 ? { count, needed: needed ?? 2, startIn, at: Date.now() } : null);
        }
        case 'cvcHud': {
          const { open, ...data } = message.data;
          setLive(null);
          setOutside(false);
          return setHud(open && data.teamId ? { ...(data as CvcHudData), at: Date.now() } : null);
        }
        case 'cvcState':
          return setLive(message.data);
        case 'cvcOutside':
          return setOutside(message.data.outside);
        case 'cvcBanner':
          return showBanner({
            title: RESULT_TITLES.round[message.data.result],
            text: message.data.reason,
            scores: message.data.scores,
            tone: TONES[message.data.result],
          });
        case 'cvcEnd':
          setHud(null);
          return showBanner({
            title: RESULT_TITLES.match[message.data.result],
            text: message.data.reason,
            scores: message.data.scores,
            tone: TONES[message.data.result],
          });
      }
    },
    [showBanner],
  );
  useNuiMessage(handleMessage);

  return (
    <>
      {queue && !hud && <CvcQueue queue={queue} />}
      {hud && <CvcHud hud={hud} live={live} />}
      {hud && outside && (
        <div className="cvc-outside">
          <span className="disp">Hors zone</span>
          <span>Reviens dans la zone de combat : tu perds de la vie</span>
        </div>
      )}
      {banner && (
        <div className={`chase-banner chase-banner--${banner.tone}`} key={banner.id}>
          <span className="disp chase-banner__title">{banner.title}</span>
          {banner.text && <span className="chase-banner__text">{banner.text}</span>}
          <span className="mono chase-banner__score">
            TON ÉQUIPE {banner.scores.us} — {banner.scores.them} ADVERSAIRES
          </span>
        </div>
      )}
    </>
  );
}

function CvcQueue({ queue }: { queue: Queue }) {
  const startIn = useSecondsLeft(queue.startIn ?? 0, queue.at);
  return (
    <div className="chase-queue">
      <span className="disp chase-queue__title">CVC</span>
      <span className="mono chase-queue__text">
        {queue.startIn !== undefined
          ? `${queue.count} joueurs · départ dans ${startIn} s`
          : `En attente de joueurs · ${queue.count}/${queue.needed}`}
      </span>
    </div>
  );
}

function CvcHud({ hud, live }: { hud: CvcHudData & { at: number }; live: CvcStateData | null }) {
  const countdown = useSecondsLeft(hud.countdown, hud.at);
  const remaining = live?.remaining ?? hud.roundTime;

  return (
    <>
      <div className={`cvc-hud cvc-hud--${hud.teamId}`}>
        <div className="cvc-hud__top">
          <span className="disp cvc-hud__team">Équipe {hud.team}</span>
          <span className="mono cvc-hud__round">MANCHE {hud.round}</span>
          <span className="mono cvc-hud__time">{formatTime(remaining)}</span>
        </div>
        <div className="cvc-hud__score">
          <span className="disp cvc-hud__us">{hud.scores.us}</span>
          <span className="mono cvc-hud__goal">PREMIÈRE À {hud.roundsToWin}</span>
          <span className="disp cvc-hud__them">{hud.scores.them}</span>
        </div>
        {live && (
          <div className="cvc-hud__alive">
            <span className="mono">EN VIE : {live.alive.us}</span>
            <span className="mono">ADVERSAIRES : {live.alive.them}</span>
          </div>
        )}
        <span className="mono cvc-hud__arena">{hud.arena.toUpperCase()}</span>
      </div>
      {countdown > 0 && (
        <div className="chase-countdown" key={countdown}>
          <span className="disp">{countdown}</span>
        </div>
      )}
    </>
  );
}
