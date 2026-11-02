import { useRef, type MouseEvent } from 'react';
import { useT } from '../../i18n';
import { currentUiScale } from '../../utils/scale';

/** Degrés de rotation par pixel de glissé */
const DEGREES_PER_PIXEL = 0.4;
/** Envoi de la rotation au jeu au plus toutes les X ms */
const ROTATE_THROTTLE = 40;

/** Zone libre à droite des menus de custom : on y voit le véhicule ou l'arme et on le tourne en glissant. */
export function CustomStage({ hint, onRotate }: { hint: string; onRotate: (delta: number) => void }) {
  const t = useT();
  const lastX = useRef<number | null>(null);
  const pending = useRef(0);
  const timer = useRef<number | null>(null);

  const queueRotation = (delta: number) => {
    pending.current += delta;
    if (timer.current !== null) return;
    timer.current = window.setTimeout(() => {
      onRotate(pending.current);
      pending.current = 0;
      timer.current = null;
    }, ROTATE_THROTTLE);
  };

  const onMouseMove = (event: MouseEvent) => {
    if (lastX.current === null) return;
    // Même vitesse de rotation quelle que soit la résolution
    queueRotation(((lastX.current - event.clientX) / currentUiScale()) * DEGREES_PER_PIXEL);
    lastX.current = event.clientX;
  };

  const stopDrag = () => {
    lastX.current = null;
  };

  return (
    <div
      className="creator-stage"
      onMouseDown={(event) => {
        lastX.current = event.clientX;
      }}
      onMouseMove={onMouseMove}
      onMouseUp={stopDrag}
      onMouseLeave={stopDrag}
    >
      <div className="creator-stage__bar" onMouseDown={(event) => event.stopPropagation()}>
        <button className="btn btn--small cut-s" onClick={() => onRotate(-45)} aria-label={t('Tourner à gauche')}>
          ⟲
        </button>
        <button className="btn btn--small cut-s" onClick={() => onRotate(45)} aria-label={t('Tourner à droite')}>
          ⟳
        </button>
      </div>
      <span className="mono creator-stage__hint">{hint}</span>
    </div>
  );
}
