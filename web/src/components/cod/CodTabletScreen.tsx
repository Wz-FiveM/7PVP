import { useCallback, useRef, useState, type CSSProperties } from 'react';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { t, useT } from '../../i18n';
import type { NuiMessage } from '../../types/nui';

const CASING_TIME = 650; // ms, à garder égal à l'animation de .cod-tablet__casing

export interface CodTabletView {
  state: 'opening' | 'flying' | 'lost';
  seconds: number;
  title: string;
  help: string[];
  /** Vue à bord : image sans cadre ni lignes de tablette, minigun au premier plan */
  clear: boolean;
}

interface TabletStatus {
  altitude?: number;
  boost?: boolean;
  weapon?: string;
  ready?: number;
  remaining?: number;
  firing?: boolean;
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

/** Tablette des séries pilotées : elle monte à l'écran, puis son cadre entoure l'image de la caméra. */
export function CodTabletScreen({ view }: { view: CodTabletView }) {
  useT();
  const [status, setStatus] = useState<TabletStatus>({});
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

  if (view.state === 'opening') {
    return (
      <div className="cod-tablet">
        <div className="cod-tablet__raise" style={{ animationDuration: `${view.seconds}s` }}>
          <span className="cod-label">{t('Liaison en cours')}</span>
        </div>
      </div>
    );
  }

  return (
    <div className="cod-tablet">
      <div className={view.clear ? 'cod-tablet__view cod-tablet__view--clear' : 'cod-tablet__view'}>
        <span className="cod-tablet__title">{t(view.title)}</span>
        <span className="cod-tablet__info">
          {status.altitude !== undefined && t('ALT {meters} M', { meters: status.altitude })}
          {status.remaining !== undefined && t('{seconds} S', { seconds: status.remaining })}
        </span>
        <span className={view.clear ? 'cod-tablet__reticle cod-tablet__reticle--small' : 'cod-tablet__reticle'} />
        {status.boost && <span className="cod-tablet__boost">{t('ACCÉLÉRATION')}</span>}
        {status.weapon && !view.clear && (
          <span className="cod-tablet__weapon">
            <span>{t(status.weapon)}</span>
            <span className="cod-xpbar">
              <span style={{ width: `${(status.ready ?? 1) * 100}%` }} />
            </span>
          </span>
        )}
        {casings.map((casing) => <span className="cod-tablet__casing" key={casing.id} style={casing.style} />)}
        <span className="cod-tablet__help">
          {view.help.map((line) => <span key={line}>{t(line)}</span>)}
        </span>
        <span className="cod-tablet__fade" />
      </div>
      {!view.clear && <span className="cod-tablet__bezel" />}
      {view.state === 'lost' && (
        <div className="cod-tablet__lost">
          <span className="cod-tablet__title">{t('Signal perdu')}</span>
        </div>
      )}
    </div>
  );
}
