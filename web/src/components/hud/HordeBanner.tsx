import { useEffect, useState } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';

/** Horde en cours : zone, temps restant et zombies tués. */
export function HordeBanner() {
  const t = useT();
  const { state } = useGame();
  const [now, setNow] = useState(Date.now);
  const horde = state.horde;

  useEffect(() => {
    if (!horde) return undefined;
    const timer = window.setInterval(() => setNow(Date.now()), 500);
    return () => window.clearInterval(timer);
  }, [horde]);

  if (!horde) return null;
  const seconds = Math.max(0, Math.ceil((horde.endsAt - now) / 1000));
  const time = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

  return (
    <div className="horde-banner zone-pve">
      <div className="stripes" />
      <div className="horde-banner__body">
        <span className="disp horde-banner__title">{t('Horde')}</span>
        <span className="horde-banner__zone">{t(horde.label)}</span>
        <span className="mono horde-banner__time">{time}</span>
        <span className="mono horde-banner__kills">{t('{kills} TUÉS', { kills: horde.kills })}</span>
      </div>
    </div>
  );
}
