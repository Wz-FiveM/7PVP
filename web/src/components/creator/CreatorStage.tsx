import { useRef, type MouseEvent } from 'react';
import { useT } from '../../i18n';
import { useCreator } from '../../store/CreatorProvider';
import type { CameraPreset } from '../../types/appearance';
import { currentUiScale } from '../../utils/scale';

const CAMERAS: { id: CameraPreset; label: string }[] = [
  { id: 'face', label: 'Visage' },
  { id: 'torso', label: 'Buste' },
  { id: 'body', label: 'Corps' },
];

/** Degrés de rotation du personnage par pixel de glissé */
const DEGREES_PER_PIXEL = 0.6;
/** Envoi de la rotation au jeu au plus toutes les X ms */
const ROTATE_THROTTLE = 40;

/** Zone libre à droite : on y voit le personnage et on le tourne en glissant. */
export function CreatorStage() {
  const t = useT();
  const { state, actions } = useCreator();
  const lastX = useRef<number | null>(null);
  const pending = useRef(0);
  const timer = useRef<number | null>(null);

  if (!state) return null;

  const queueRotation = (delta: number) => {
    pending.current += delta;
    if (timer.current !== null) return;
    timer.current = window.setTimeout(() => {
      actions.rotate(pending.current);
      pending.current = 0;
      timer.current = null;
    }, ROTATE_THROTTLE);
  };

  const onMouseMove = (event: MouseEvent) => {
    if (lastX.current === null) return;
    // Même vitesse de rotation quelle que soit la résolution
    queueRotation(((event.clientX - lastX.current) / currentUiScale()) * DEGREES_PER_PIXEL);
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
        <button className="btn btn--small cut-s" onClick={() => actions.rotate(-45)} aria-label={t('Tourner à gauche')}>
          ⟲
        </button>
        {CAMERAS.map((camera) => (
          <button
            key={camera.id}
            className={camera.id === state.camera ? 'btn btn--small btn--active cut-s' : 'btn btn--small cut-s'}
            onClick={() => actions.setCamera(camera.id)}
          >
            {t(camera.label)}
          </button>
        ))}
        <button className="btn btn--small cut-s" onClick={() => actions.rotate(45)} aria-label={t('Tourner à droite')}>
          ⟳
        </button>
      </div>
      <span className="mono creator-stage__hint">{t('[GLISSER] TOURNER LE PERSONNAGE')}</span>
    </div>
  );
}
