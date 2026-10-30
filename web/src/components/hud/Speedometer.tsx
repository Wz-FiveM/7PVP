import { useCallback, useState } from 'react';
import { useT } from '../../i18n';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import type { NuiMessage } from '../../types/nui';
import type { SpeedometerData } from '../../types/game';
import './speedometer.css';

const RPM_SEGMENTS = 18;
/** Derniers segments en rouge : zone rouge du compte-tours */
const REDLINE = 0.85;

/** Compteur de vitesse, affiché en véhicule en Freeroam (bas droite, au-dessus des munitions). */
export function Speedometer() {
  const t = useT();
  const [data, setData] = useState<SpeedometerData | null>(null);

  const handleMessage = useCallback((message: NuiMessage) => {
    if (message.action !== 'speedometer') return;
    setData(message.data.visible ? message.data : null);
  }, []);
  useNuiMessage(handleMessage);

  if (!data) return null;

  // GTA donne un régime de 0,2 (ralenti) à 1,0 : ramené de 0 à 1
  const rpm = Math.max(0, Math.min(1, ((data.rpm ?? 0) - 0.2) / 0.8));
  const lit = Math.round(rpm * RPM_SEGMENTS);
  const engine = data.engine ?? 100;

  return (
    <div className="speedometer">
      <div className="speedometer__main">
        <span className="disp speedometer__speed">{data.speed ?? 0}</span>
        <div className="speedometer__side">
          <span className="mono speedometer__unit">KM/H</span>
          <span className="disp speedometer__gear">{data.gear ?? 'N'}</span>
        </div>
      </div>
      <div className="speedometer__rpm" aria-label={t('Régime moteur')}>
        {Array.from({ length: RPM_SEGMENTS }, (_, index) => {
          const red = index >= Math.floor(RPM_SEGMENTS * REDLINE);
          const on = index < lit;
          return (
            <span
              key={index}
              className={[
                'speedometer__cell',
                on && 'speedometer__cell--on',
                on && red && 'speedometer__cell--red',
              ].filter(Boolean).join(' ')}
            />
          );
        })}
      </div>
      <span className={engine < 35 ? 'mono speedometer__engine speedometer__engine--low' : 'mono speedometer__engine'}>
        {t('MOTEUR {engine} %', { engine })}
      </span>
    </div>
  );
}
