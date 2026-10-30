import { useCallback, useEffect, useState } from 'react';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { t, useT } from '../../i18n';
import type { EloChange, GunfightHudData, GunfightScores } from '../../types/game';
import type { NuiMessage } from '../../types/nui';
import { EloDelta } from './EloDelta';
import './chase.css';
import './cvc.css';

const RESULT_TITLES = {
  round: { won: 'Manche gagnée', lost: 'Manche perdue', draw: 'Manche nulle' },
  match: { won: 'Victoire', lost: 'Défaite', draw: 'Égalité' },
};
const TONES = { won: 'good', lost: 'bad', draw: 'neutral' } as const;
const BANNER_TIME = 5000;

interface Banner {
  title: string;
  text?: string;
  scores: GunfightScores;
  elo?: EloChange;
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

/** 1VS1 (GunFight, Bike) : file d'attente, HUD de manche (score, adversaire, temps), hors zone, résultats. */
export function Gunfight() {
  useT();
  /** Nom du mode dont on attend un adversaire, null hors file */
  const [queue, setQueue] = useState<string | null>(null);
  const [hud, setHud] = useState<(GunfightHudData & { at: number }) | null>(null);
  const [remaining, setRemaining] = useState<number | null>(null);
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
        case 'gunfightQueue':
          return setQueue(message.data.count > 0 ? (message.data.label ?? '1VS1') : null);
        case 'gunfightHud': {
          const { open, ...data } = message.data;
          setRemaining(null);
          setOutside(false);
          return setHud(open && data.opponent ? { ...(data as GunfightHudData), at: Date.now() } : null);
        }
        case 'gunfightState':
          return setRemaining(message.data.remaining);
        case 'gunfightOutside':
          return setOutside(message.data.outside);
        case 'gunfightBanner':
          return showBanner({
            title: RESULT_TITLES.round[message.data.result],
            text: message.data.reason,
            scores: message.data.scores,
            tone: TONES[message.data.result],
          });
        case 'gunfightEnd':
          setHud(null);
          return showBanner({
            title: RESULT_TITLES.match[message.data.result],
            text: message.data.reason,
            scores: message.data.scores,
            elo: message.data.elo,
            tone: TONES[message.data.result],
          });
      }
    },
    [showBanner],
  );
  useNuiMessage(handleMessage);

  return (
    <>
      {queue && !hud && (
        <div className="chase-queue">
          <span className="disp chase-queue__title">{t(queue)}</span>
          <span className="mono chase-queue__text">{t("En attente d'un adversaire · {count}/2", { count: 1 })}</span>
        </div>
      )}
      {hud && <GunfightHud hud={hud} remaining={remaining} />}
      {hud && outside && (
        <div className="cvc-outside">
          <span className="disp">{t('Hors zone')}</span>
          <span>{t('Reviens dans la zone de combat : tu perds de la vie')}</span>
        </div>
      )}
      {banner && (
        <div className={`chase-banner chase-banner--${banner.tone}`} key={banner.id}>
          <span className="disp chase-banner__title">{t(banner.title)}</span>
          {banner.text && <span className="chase-banner__text">{banner.text}</span>}
          <span className="mono chase-banner__score">
            {t('TOI {me} — {opponent} ADVERSAIRE', { me: banner.scores.us, opponent: banner.scores.them })}
          </span>
          {banner.elo && <EloDelta elo={banner.elo} />}
        </div>
      )}
    </>
  );
}

function GunfightHud({ hud, remaining }: { hud: GunfightHudData & { at: number }; remaining: number | null }) {
  useT();
  const countdown = useSecondsLeft(hud.countdown, hud.at);

  return (
    <>
      <div className="cvc-hud">
        <div className="cvc-hud__top">
          <span className="disp cvc-hud__team">1VS1</span>
          <span className="mono cvc-hud__round">{t('MANCHE {round}', { round: hud.round })}</span>
          <span className="mono cvc-hud__time">{formatTime(remaining ?? hud.roundTime)}</span>
        </div>
        <div className="cvc-hud__score">
          <span className="disp cvc-hud__us">{hud.scores.us}</span>
          <span className="mono cvc-hud__goal">{t('PREMIER À {rounds}', { rounds: hud.roundsToWin })}</span>
          <span className="disp cvc-hud__them">{hud.scores.them}</span>
        </div>
        <span className="mono cvc-hud__arena">{t('CONTRE {name}', { name: hud.opponent.toUpperCase() })}</span>
      </div>
      {countdown > 0 && (
        <div className="chase-countdown" key={countdown}>
          <span className="disp">{countdown}</span>
        </div>
      )}
    </>
  );
}
