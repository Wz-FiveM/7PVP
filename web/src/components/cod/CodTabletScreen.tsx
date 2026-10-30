import { useCallback, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { t, useT } from '../../i18n';
import type { CodTabletStatus } from '../../types/cod';
import type { NuiMessage } from '../../types/nui';
import './codTablet.css';

const CASING_TIME = 650; // ms, à garder égal à l'animation de .cod-tablet__casing
const COMPASS_SPAN = 50; // degrés de part et d'autre du cap
const COMPASS_STEP = 10;
const COMPASS_MAJOR = 30;
const COMPASS_POINTS: Record<number, string> = { 0: 'N', 90: 'E', 180: 'S', 270: 'O' };
const ALTITUDE_SPAN = 60; // m de part et d'autre de l'altitude
const ALTITUDE_STEP = 10;
const ALTITUDE_MAJOR = 50;
const RETICLE_BASE = 7; // vh
const RETICLE_PER_METER = 1.1; // vh par mètre de rayon de l'arme

export interface CodTabletView {
  state: 'opening' | 'flying' | 'lost';
  seconds: number;
  title: string;
  help: string[];
  /** Vue à bord : image sans cadre ni lignes de tablette, minigun au premier plan */
  clear: boolean;
}

interface Casing {
  id: number;
  style: CSSProperties;
}

/** Douille éjectée vers la droite du minigun, chacune sur sa propre trajectoire. */
function casingStyle(): CSSProperties {
  return {
    '--drift': `${6 + Math.random() * 14}vw`,
    '--rise': `${4 + Math.random() * 12}vh`,
    '--spin': `${(Math.random() < 0.5 ? -1 : 1) * (240 + Math.random() * 360)}deg`,
  } as CSSProperties;
}

const modulo = (value: number, by: number) => ((value % by) + by) % by;
/** Cap du jeu (sens inverse des aiguilles d'une montre) vers un cap de boussole. */
const toCompass = (heading: number) => modulo(-heading, 360);
const pad = (value: number, size: number) => String(Math.abs(Math.round(value))).padStart(size, '0');

/** Bande de cap qui défile en haut de l'image. */
function CompassTape({ heading }: { heading: number }) {
  const ticks: ReactNode[] = [];
  const first = Math.ceil((heading - COMPASS_SPAN) / COMPASS_STEP) * COMPASS_STEP;
  for (let degree = first; degree <= heading + COMPASS_SPAN; degree += COMPASS_STEP) {
    const value = modulo(degree, 360);
    const major = value % COMPASS_MAJOR === 0;
    ticks.push(
      <span
        className={major ? 'cod-tablet__tick cod-tablet__tick--major' : 'cod-tablet__tick'}
        key={degree}
        style={{ left: `${50 + ((degree - heading) / COMPASS_SPAN) * 50}%` }}
      >
        {major && <b>{COMPASS_POINTS[value] ?? pad(value, 3)}</b>}
      </span>,
    );
  }
  return (
    <div className="cod-tablet__compass">
      <div className="cod-tablet__compass-tape">{ticks}</div>
      <span className="cod-tablet__compass-value">{pad(heading, 3)}°</span>
    </div>
  );
}

/** Échelle d'altitude qui défile à gauche de l'image. */
function AltitudeTape({ altitude }: { altitude: number }) {
  const ticks: ReactNode[] = [];
  const first = Math.max(0, Math.ceil((altitude - ALTITUDE_SPAN) / ALTITUDE_STEP) * ALTITUDE_STEP);
  for (let meters = first; meters <= altitude + ALTITUDE_SPAN; meters += ALTITUDE_STEP) {
    const major = meters % ALTITUDE_MAJOR === 0;
    ticks.push(
      <span
        className={major ? 'cod-tablet__rung cod-tablet__rung--major' : 'cod-tablet__rung'}
        key={meters}
        style={{ top: `${50 - ((meters - altitude) / ALTITUDE_SPAN) * 50}%` }}
      >
        {major && <b>{meters}</b>}
      </span>,
    );
  }
  return (
    <div className="cod-tablet__altitude">
      {ticks}
      <span className="cod-tablet__altitude-value">{Math.round(altitude)}</span>
    </div>
  );
}

function Readout({ label, value, alert }: { label: string; value: string; alert?: boolean }) {
  return (
    <span className={alert ? 'cod-tablet__readout cod-tablet__readout--alert' : 'cod-tablet__readout'}>
      <span>{label}</span>
      <b>{value}</b>
    </span>
  );
}

/** Cadre de visée : sa taille suit la zone touchée par l'arme, le centre reste le point d'impact. */
function Reticle({ radius, small }: { radius?: number; small: boolean }) {
  const size = small ? undefined : `${radius === undefined ? 20 : RETICLE_BASE + radius * RETICLE_PER_METER}vh`;
  return (
    <span className={small ? 'cod-tablet__reticle cod-tablet__reticle--small' : 'cod-tablet__reticle'} style={{ width: size, height: size }}>
      {!small && (
        <>
          <i className="cod-tablet__corner cod-tablet__corner--tl" />
          <i className="cod-tablet__corner cod-tablet__corner--tr" />
          <i className="cod-tablet__corner cod-tablet__corner--bl" />
          <i className="cod-tablet__corner cod-tablet__corner--br" />
        </>
      )}
      <i className="cod-tablet__cross" />
    </span>
  );
}

/** La tablette durcie qui monte à l'écran, le temps que la liaison s'établisse. */
function Opening({ view }: { view: CodTabletView }) {
  useT();
  return (
    <div className="cod-tablet">
      <div className="cod-tablet__raise" style={{ animationDuration: `${view.seconds}s` }}>
        <i className="cod-tablet__screw cod-tablet__screw--tl" />
        <i className="cod-tablet__screw cod-tablet__screw--tr" />
        <i className="cod-tablet__screw cod-tablet__screw--bl" />
        <i className="cod-tablet__screw cod-tablet__screw--br" />
        <i className="cod-tablet__led" />
        <div className="cod-tablet__boot">
          <span className="cod-tablet__boot-title">{t(view.title)}</span>
          <span className="cod-tablet__boot-line" style={{ animationDelay: `${view.seconds * 0.1}s` }}>{t('Initialisation du système')}</span>
          <span className="cod-tablet__boot-line" style={{ animationDelay: `${view.seconds * 0.2}s` }}>{t('Recherche du satellite')}</span>
          <span className="cod-tablet__boot-line" style={{ animationDelay: `${view.seconds * 0.3}s` }}>{t('Chiffrement de la liaison')}</span>
          <span className="cod-tablet__boot-bar">
            <span style={{ animationDuration: `${view.seconds * 0.6}s` }} />
          </span>
          <span className="cod-tablet__boot-status">{t('Liaison en cours')}</span>
        </div>
      </div>
    </div>
  );
}

/** Tablette des séries pilotées : elle monte à l'écran, puis son cadre entoure l'image de la caméra. */
export function CodTabletScreen({ view }: { view: CodTabletView }) {
  useT();
  const [status, setStatus] = useState<CodTabletStatus>({});
  const [casings, setCasings] = useState<Casing[]>([]);
  const nextCasing = useRef(0);

  const handleMessage = useCallback((message: NuiMessage) => {
    if (message.action !== 'codTabletStatus') return;
    setStatus(message.data);
    if (!message.data.firing) return;
    const id = ++nextCasing.current;
    setCasings((current) => [...current, { id, style: casingStyle() }]);
    window.setTimeout(() => setCasings((current) => current.filter((casing) => casing.id !== id)), CASING_TIME);
  }, []);
  useNuiMessage(handleMessage);

  if (view.state === 'opening') return <Opening view={view} />;

  const heading = status.heading === undefined ? undefined : toCompass(status.heading);
  const ready = status.ready ?? 1;
  return (
    <div className="cod-tablet">
      <div className={view.clear ? 'cod-tablet__view cod-tablet__view--clear' : 'cod-tablet__view'}>
        <div className="cod-tablet__head">
          <span className="cod-tablet__title">{t(view.title)}</span>
          {!view.clear && (
            <span className="cod-tablet__link">
              <i className="cod-tablet__rec" />
              REC · {new Date().toISOString().slice(11, 19)}Z · {t('Liaison sécurisée')}
            </span>
          )}
        </div>

        {!view.clear && heading !== undefined && <CompassTape heading={heading} />}
        {!view.clear && status.altitude !== undefined && <AltitudeTape altitude={status.altitude} />}

        <div className="cod-tablet__readouts">
          {!view.clear && status.altitude !== undefined && <Readout label={t('ALT')} value={`${status.altitude} M`} />}
          {!view.clear && status.speed !== undefined && <Readout label={t('VIT')} value={`${status.speed} M/S`} alert={status.boost} />}
          {!view.clear && status.impact !== undefined && <Readout label={t('IMPACT')} value={`${status.impact.toFixed(1)} S`} alert={status.impact < 3} />}
          {!view.clear && status.range !== undefined && <Readout label={t('PORTÉE')} value={`${status.range} M`} />}
          {status.remaining !== undefined && <Readout label={t('TEMPS')} value={`${status.remaining} S`} alert={status.remaining <= 5} />}
        </div>

        <Reticle radius={status.radius} small={view.clear} />
        {status.boost && <span className="cod-tablet__boost">{t('ACCÉLÉRATION')}</span>}

        {!view.clear && status.x !== undefined && status.y !== undefined && (
          <span className="cod-tablet__grid">
            <span>{t('CIBLE')}</span>
            <b>{pad(status.x, 5)} {pad(status.y, 5)}</b>
            {status.pitch !== undefined && <span>{t('SITE')} {Math.round(status.pitch)}°</span>}
          </span>
        )}

        {status.weapon && !view.clear && (
          <span className={ready >= 1 ? 'cod-tablet__weapon cod-tablet__weapon--ready' : 'cod-tablet__weapon'}>
            <span className="cod-tablet__weapon-head">
              <b>{t(status.weapon)}</b>
              <span>{ready >= 1 ? t('PRÊT') : t('RECHARGE')}</span>
            </span>
            <span className="cod-tablet__weapon-bar">
              <span style={{ width: `${ready * 100}%` }} />
            </span>
          </span>
        )}
        {casings.map((casing) => <span className="cod-tablet__casing" key={casing.id} style={casing.style} />)}
        <span className="cod-tablet__help">
          {view.help.map((line) => <span key={line}>{t(line)}</span>)}
        </span>
        <span className="cod-tablet__fade" />
      </div>
      {!view.clear && (
        <>
          <span className="cod-tablet__glass" />
          <span className="cod-tablet__bezel">
            <i className="cod-tablet__led" />
          </span>
        </>
      )}
      {view.state === 'lost' && (
        <div className="cod-tablet__lost">
          <div className="cod-tablet__lost-box">
            <b>{t('Signal perdu')}</b>
            <span>{t('Liaison interrompue')}</span>
          </div>
        </div>
      )}
    </div>
  );
}
