import { useGame } from '../../store/GameContext';
import type { ZoneType } from '../../types/game';

const TAG: Record<ZoneType, string> = { safe: 'Zone safe', pve: 'Zone PvE', pvp: 'Zone PvP' };
const DETAIL: Record<ZoneType, string> = {
  safe: 'Tir désactivé · boutique disponible',
  pve: 'PNJ hostiles · PvP actif',
  pvp: 'Combat libre entre joueurs',
};

/** Zone courante, en haut à gauche, dans la couleur de la zone. */
export function ZoneBanner() {
  const { state } = useGame();
  const { zone } = state;
  const name = zone.type === 'pvp' ? 'Territoire libre' : zone.label.replace(/^Zone (safe|PvP|PvE)\s*-\s*/i, '');

  return (
    <div className={`zone-banner zone-${zone.type}`}>
      <div className="stripes" />
      <div className="zone-banner__body cut">
        <span className="chip cut-s">{TAG[zone.type]}</span>
        <span className="disp zone-banner__name">{name}</span>
        <span className="muted zone-banner__detail">{DETAIL[zone.type]}</span>
      </div>
    </div>
  );
}
