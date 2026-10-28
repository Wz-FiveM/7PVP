import { useGame } from '../../store/GameContext';
import { SegmentBar } from '../ui/SegmentBar';

/** Zone de contrôle où se trouve le joueur : propriétaire et capture en cours. */
export function ControlZoneBar() {
  const { state } = useGame();
  const zone = state.controlZone;
  if (!zone) return null;

  let status = zone.ownerLabel ? `Tenue par ${zone.ownerLabel}` : 'Zone neutre';
  if (zone.mine) status = 'Tenue par ton camp';
  if (zone.capturing) status = `Capture ${zone.progress} %`;
  if (zone.enemyCapturing) status = `Capture ennemie ${zone.progress} %`;
  if (zone.contested) status = 'Contestée';
  const color = zone.contested || zone.enemyCapturing ? 'var(--hazard)' : 'var(--toxine)';

  return (
    <div className={zone.contested ? 'control-bar control-bar--contested' : 'control-bar'}>
      <div className="control-bar__head">
        <span className="disp control-bar__label">{zone.label}</span>
        <span className="mono control-bar__status">{status}</span>
      </div>
      {(zone.capturing || zone.enemyCapturing) && (
        <SegmentBar value={zone.progress} max={100} segments={20} color={color} height={5} />
      )}
    </div>
  );
}
