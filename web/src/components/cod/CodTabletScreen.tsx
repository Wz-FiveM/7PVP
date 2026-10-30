import { useCallback, useState } from 'react';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { t, useT } from '../../i18n';
import type { NuiMessage } from '../../types/nui';

export interface CodPredatorView {
  state: 'opening' | 'flying' | 'lost';
  seconds: number;
}

/** Tablette du missile Predator : elle monte à l'écran, puis son cadre entoure l'image du missile. */
export function CodPredatorScreen({ view }: { view: CodPredatorView }) {
  useT();
  const [status, setStatus] = useState({ altitude: 0, boost: false });

  const handleMessage = useCallback((message: NuiMessage) => {
    if (message.action === 'codPredatorStatus') setStatus(message.data);
  }, []);
  useNuiMessage(handleMessage);

  if (view.state === 'opening') {
    return (
      <div className="cod-predator">
        <div className="cod-predator__raise" style={{ animationDuration: `${view.seconds}s` }}>
          <span className="cod-label">{t('Liaison au missile')}</span>
        </div>
      </div>
    );
  }

  return (
    <div className="cod-predator">
      <div className="cod-predator__view">
        <span className="cod-predator__title">{t('Missile Predator')}</span>
        <span className="cod-predator__altitude">{t('ALT {meters} M', { meters: status.altitude })}</span>
        <span className="cod-predator__reticle" />
        {status.boost && <span className="cod-predator__boost">{t('ACCÉLÉRATION')}</span>}
        <span className="cod-predator__help">
          <span>{t('Souris : diriger')}</span>
          <span>{t('Clic gauche : accélérer')}</span>
        </span>
        <span className="cod-predator__fade" />
      </div>
      <span className="cod-predator__bezel" />
      {view.state === 'lost' && (
        <div className="cod-predator__lost">
          <span className="cod-predator__title">{t('Signal perdu')}</span>
        </div>
      )}
    </div>
  );
}
