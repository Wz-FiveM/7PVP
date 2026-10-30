import { useCallback, useEffect, useState, type CSSProperties } from 'react';
import { useT } from '../../i18n';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import type { EffectHud } from '../../types/game';
import type { NuiMessage } from '../../types/nui';
import './effects.css';

const TICK = 250;
/** En dessous, l'effet clignote en rouge : il va bientôt s'arrêter */
const ENDING_SOON = 10;

interface ActiveEffect extends EffectHud {
  /** fin de l'effet (Date.now()) */
  endsAt: number;
}

/** Effets des stimulants en cours (bas droite, au-dessus des munitions) : icône et temps restant. */
export function EffectsBar({ hidden }: { hidden: boolean }) {
  const t = useT();
  const [effects, setEffects] = useState<ActiveEffect[]>([]);
  const [now, setNow] = useState(Date.now);

  const handleMessage = useCallback((message: NuiMessage) => {
    if (message.action !== 'effects') return;
    // Une liste vide peut arriver de Lua sous forme d'objet : on ne garde que les tableaux
    const list = Array.isArray(message.data) ? message.data : [];
    const at = Date.now();
    setNow(at);
    setEffects(list.map((effect) => ({ ...effect, endsAt: at + effect.remaining * 1000 })));
  }, []);
  useNuiMessage(handleMessage);

  useEffect(() => {
    if (effects.length === 0) return undefined;
    const timer = window.setInterval(() => setNow(Date.now()), TICK);
    return () => window.clearInterval(timer);
  }, [effects.length]);

  const visible = effects.filter((effect) => effect.endsAt > now);
  if (hidden || visible.length === 0) return null;

  return (
    <div className="effects">
      {visible.map((effect) => {
        const seconds = Math.ceil((effect.endsAt - now) / 1000);
        const ratio = Math.min(1, (effect.endsAt - now) / (effect.duration * 1000));
        const ending = seconds <= ENDING_SOON;
        return (
          <div
            key={effect.id}
            className={ending ? 'effect effect--ending' : 'effect'}
            title={t(effect.label)}
            style={{ '--effect-progress': `${ratio * 100}%` } as CSSProperties}
          >
            <div className="effect__tile">
              <img className="effect__icon" src={`./items/${effect.icon}.png`} alt="" draggable={false} />
              <span className="mono effect__time">{formatSeconds(seconds)}</span>
              <span className="effect__bar" />
            </div>
            <span className="disp effect__name">{t(effect.short)}</span>
          </div>
        );
      })}
    </div>
  );
}

function formatSeconds(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}:${String(seconds % 60).padStart(2, '0')}`;
}
