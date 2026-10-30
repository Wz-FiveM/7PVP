import { useCallback, useState } from 'react';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { t, useT } from '../../i18n';
import type { NuiMessage } from '../../types/nui';

export interface CodTabletView {
  state: 'opening' | 'flying' | 'lost';
  seconds: number;
  title: string;
  help: string[];
}

interface TabletStatus {
  altitude?: number;
  boost?: boolean;
  weapon?: string;
  ready?: number;
  remaining?: number;
}

/** Tablette des séries pilotées : elle monte à l'écran, puis son cadre entoure l'image de la caméra. */
export function CodTabletScreen({ view }: { view: CodTabletView }) {
  useT();
  const [status, setStatus] = useState<TabletStatus>({});

  const handleMessage = useCallback((message: NuiMessage) => {
    if (message.action === 'codTabletStatus') setStatus(message.data);
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
      <div className="cod-tablet__view">
        <span className="cod-tablet__title">{t(view.title)}</span>
        <span className="cod-tablet__info">
          {status.altitude !== undefined && t('ALT {meters} M', { meters: status.altitude })}
          {status.remaining !== undefined && t('{seconds} S', { seconds: status.remaining })}
        </span>
        <span className="cod-tablet__reticle" />
        {status.boost && <span className="cod-tablet__boost">{t('ACCÉLÉRATION')}</span>}
        {status.weapon && (
          <span className="cod-tablet__weapon">
            <span>{t(status.weapon)}</span>
            <span className="cod-xpbar">
              <span style={{ width: `${(status.ready ?? 1) * 100}%` }} />
            </span>
          </span>
        )}
        <span className="cod-tablet__help">
          {view.help.map((line) => <span key={line}>{t(line)}</span>)}
        </span>
        <span className="cod-tablet__fade" />
      </div>
      <span className="cod-tablet__bezel" />
      {view.state === 'lost' && (
        <div className="cod-tablet__lost">
          <span className="cod-tablet__title">{t('Signal perdu')}</span>
        </div>
      )}
    </div>
  );
}
