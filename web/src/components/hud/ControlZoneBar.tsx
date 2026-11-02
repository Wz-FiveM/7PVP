import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { SegmentBar } from '../ui/SegmentBar';

/** Zone de contrôle ou territoire où se trouve le joueur : propriétaire et capture en cours. */
export function ControlZoneBar() {
  const t = useT();
  const { state } = useGame();
  const zone = state.controlZone;
  if (!zone) return null;

  let status = zone.ownerLabel ? t('Tenue par {owner}', { owner: zone.ownerLabel }) : t('Zone neutre');
  if (zone.mine) status = t('Tenue par ton camp');
  if (zone.territory) {
    status = zone.ownerLabel ? t('Tenu par {owner}', { owner: zone.ownerLabel }) : t('Libre');
    if (zone.mine) status = t('Tenu par ton crew');
  }
  if (zone.capturing) status = t('Capture {progress} %', { progress: zone.progress });
  if (zone.enemyCapturing) status = t('Capture ennemie {progress} %', { progress: zone.progress });
  if (zone.contested) status = zone.territory ? t('Contesté') : t('Contestée');
  const color = zone.contested || zone.enemyCapturing ? 'var(--hazard)' : 'var(--toxine)';

  let hint = '';
  if (zone.noCrew) hint = t('Il te faut un crew pour capturer un territoire.');
  else if (zone.protected && !zone.mine) hint = t('Territoire protégé juste après sa prise.');
  else if (zone.atLimit) hint = t('Ton crew a déjà le maximum de territoires.');

  return (
    <div className={`control-bar${zone.contested ? ' control-bar--contested' : ''}${zone.territory ? ' control-bar--territory' : ''}`}>
      <div className="control-bar__head">
        <span className="disp control-bar__label">{zone.territory ? t('Territoire : {zone}', { zone: t(zone.label) }) : t(zone.label)}</span>
        <span className="mono control-bar__status">{status}</span>
      </div>
      {(zone.capturing || zone.enemyCapturing) && (
        <SegmentBar value={zone.progress} max={100} segments={20} color={color} height={5} />
      )}
      {hint && <span className="control-bar__hint">{hint}</span>}
    </div>
  );
}
