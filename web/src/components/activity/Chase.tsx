import { useCallback, useEffect, useState } from 'react';
import { chaseApi } from '../../api/chaseApi';
import { isEnvBrowser } from '../../api/nui';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import type { ChaseHudData, ChaseScores, ChaseStateData } from '../../types/game';
import type { NuiMessage } from '../../types/nui';
import { Icon } from '../icons/Icon';
import './chase.css';

const ROLE_LABELS = { thief: 'Voleur', cop: 'Policier' };
const RESULT_LABELS = { won: 'Victoire', lost: 'Défaite', draw: 'Égalité' };
const BANNER_TIME = 5000;

interface Vote {
  vehicles: { model: string; label: string }[];
  seconds: number;
  opponent: string;
  at: number;
}

interface Banner {
  title: string;
  text?: string;
  scores: ChaseScores;
  tone: 'good' | 'bad' | 'neutral';
  id: number;
}

const formatTime = (seconds: number) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

/** Secondes restantes d'un compte à rebours lancé à `at`. */
function useSecondsLeft(total: number, at: number): number {
  const [now, setNow] = useState(Date.now);
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 200);
    return () => window.clearInterval(timer);
  }, [at]);
  return Math.max(0, Math.ceil(total - (now - at) / 1000));
}

/** Course poursuite : file d'attente, vote du véhicule, HUD de manche, résultats. */
export function Chase() {
  const [queue, setQueue] = useState(0);
  const [vote, setVote] = useState<Vote | null>(null);
  const [hud, setHud] = useState<(ChaseHudData & { at: number }) | null>(null);
  const [live, setLive] = useState<ChaseStateData | null>(null);
  const [banner, setBanner] = useState<Banner | null>(null);

  const showBanner = useCallback((next: Omit<Banner, 'id'>) => {
    const id = Date.now();
    setBanner({ ...next, id });
    window.setTimeout(() => setBanner((current) => (current?.id === id ? null : current)), BANNER_TIME);
  }, []);

  const handleMessage = useCallback(
    (message: NuiMessage) => {
      switch (message.action) {
        case 'chaseQueue':
          return setQueue(message.data.count);
        case 'chaseVote': {
          const { open, vehicles, seconds, opponent } = message.data;
          return setVote(open && vehicles ? { vehicles, seconds: seconds ?? 20, opponent: opponent ?? '', at: Date.now() } : null);
        }
        case 'chaseHud': {
          const { open, ...data } = message.data;
          setLive(null);
          return setHud(open && data.role ? { ...(data as ChaseHudData), at: Date.now() } : null);
        }
        case 'chaseState':
          return setLive(message.data);
        case 'chaseBanner':
          return showBanner({
            title: message.data.won ? 'Manche gagnée' : 'Manche perdue',
            text: message.data.reason,
            scores: message.data.scores,
            tone: message.data.won ? 'good' : 'bad',
          });
        case 'chaseEnd':
          setHud(null);
          return showBanner({
            title: RESULT_LABELS[message.data.result],
            text: message.data.reason,
            scores: message.data.scores,
            tone: message.data.result === 'won' ? 'good' : message.data.result === 'lost' ? 'bad' : 'neutral',
          });
      }
    },
    [showBanner],
  );
  useNuiMessage(handleMessage);

  return (
    <>
      {queue > 0 && !hud && !vote && (
        <div className="chase-queue">
          <span className="disp chase-queue__title">Course poursuite</span>
          <span className="mono chase-queue__text">En attente d'un adversaire · {queue}/2</span>
        </div>
      )}
      {vote && <ChaseVote vote={vote} onDone={() => isEnvBrowser() && setVote(null)} />}
      {hud && <ChaseHud hud={hud} live={live} />}
      {banner && (
        <div className={`chase-banner chase-banner--${banner.tone}`} key={banner.id}>
          <span className="disp chase-banner__title">{banner.title}</span>
          {banner.text && <span className="chase-banner__text">{banner.text}</span>}
          <span className="mono chase-banner__score">
            TOI {banner.scores.me} — {banner.scores.opponent} ADVERSAIRE
          </span>
        </div>
      )}
    </>
  );
}

function ChaseVote({ vote, onDone }: { vote: Vote; onDone: () => void }) {
  const left = useSecondsLeft(vote.seconds, vote.at);
  const [chosen, setChosen] = useState<string | null>(null);

  const choose = async (model: string) => {
    setChosen(model);
    const result = await chaseApi.vote(model);
    if (result?.ok) onDone();
  };

  return (
    <div className="chase-vote">
      <section className="chase-vote__panel">
        <div className="stripes chase-vote__line" />
        <header className="chase-vote__header">
          <div>
            <span className="mono chase-vote__tag">Course poursuite · contre {vote.opponent}</span>
            <h1 className="disp chase-vote__title">Choisis ton véhicule</h1>
          </div>
          <span className="mono chase-vote__timer">{left} s</span>
        </header>
        <p className="muted chase-vote__hint">
          Ton véhicule servira pour la manche où tu es le voleur. Sans vote, il est tiré au sort.
        </p>
        <div className="chase-vote__grid">
          {vote.vehicles.map((vehicle) => (
            <button
              key={vehicle.model}
              className={vehicle.model === chosen ? 'chase-vote__vehicle chase-vote__vehicle--chosen' : 'chase-vote__vehicle'}
              onClick={() => choose(vehicle.model)}
            >
              <VehicleImage model={vehicle.model} />
              <span className="disp">{vehicle.label}</span>
            </button>
          ))}
        </div>
      </section>
    </div>
  );
}

function VehicleImage({ model }: { model: string }) {
  const [missing, setMissing] = useState(false);
  if (missing) return <Icon name="vehicle" size={40} strokeWidth={1.4} className="chase-vote__icon" />;
  return <img className="chase-vote__image" src={`./items/${model}.png`} alt="" draggable={false} onError={() => setMissing(true)} />;
}

function ChaseHud({ hud, live }: { hud: ChaseHudData & { at: number }; live: ChaseStateData | null }) {
  const countdown = useSecondsLeft(hud.countdown, hud.at);
  const thief = hud.role === 'thief';
  const remaining = live?.remaining ?? hud.roundTime;

  return (
    <>
      <div className={`chase-hud chase-hud--${hud.role}`}>
        <div className="chase-hud__top">
          <span className="disp chase-hud__role">{ROLE_LABELS[hud.role]}</span>
          <span className="mono chase-hud__round">MANCHE {hud.round}/2</span>
          <span className="mono chase-hud__score">
            {hud.scores.me} — {hud.scores.opponent}
          </span>
          <span className="mono chase-hud__time">{formatTime(remaining)}</span>
        </div>
        <p className="chase-hud__goal">
          {thief
            ? `Fuis : mets ${hud.escapeDistance.toLocaleString('fr-FR')} m entre toi et le policier`
            : `Immobilise le voleur ${hud.arrestTime} s, ou empêche-le de fuir`}
        </p>
        {/* Pas de distance affichée : le voleur ne sait pas s'il a semé le policier, et inversement */}
        {live && (
          <div className="chase-hud__status">
            {live.health !== undefined && (
              <div className="chase-hud__health">
                <span className="mono">VÉHICULE {live.health} %</span>
                <div className="chase-hud__bar">
                  <div
                    className={live.health < 30 ? 'chase-hud__fill chase-hud__fill--danger' : 'chase-hud__fill'}
                    style={{ width: `${live.health}%` }}
                  />
                </div>
              </div>
            )}
            {live.maxWarns !== undefined && (
              <span className={live.warns ? 'mono chase-hud__warns chase-hud__warns--on' : 'mono chase-hud__warns'}>
                AVERTISSEMENTS {live.warns ?? 0}/{live.maxWarns}
              </span>
            )}
          </div>
        )}
        {live && live.arrest > 0 && (
          <div className="chase-hud__arrest">
            <span className="disp">Immobilisation</span>
            <div className="chase-hud__bar chase-hud__bar--arrest">
              <div className="chase-hud__fill" style={{ width: `${Math.min(100, live.arrest * 100)}%` }} />
            </div>
          </div>
        )}
      </div>
      {countdown > 0 && (
        <div className="chase-countdown" key={countdown}>
          <span className="disp">{countdown}</span>
        </div>
      )}
    </>
  );
}
