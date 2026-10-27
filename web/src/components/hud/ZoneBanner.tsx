import { useEffect, useState } from 'react';
import { useGame } from '../../store/GameContext';
import type { ZoneType } from '../../types/game';

const TAG: Record<ZoneType, string> = { safe: 'Zone safe', pve: 'Zone PvE', pvp: 'Zone PvP' };
const DETAIL: Record<ZoneType, string> = {
  safe: 'Tir désactivé · boutique disponible',
  pve: 'PNJ hostiles · PvP actif',
  pvp: 'Combat libre entre joueurs',
};

/** Durée d'affichage de la bannière complète après un changement de zone */
const EXPANDED_DURATION = 5000;

/**
 * Zone courante, en haut à gauche, dans la couleur de la zone.
 * Bannière complète quelques secondes à l'entrée d'une zone, puis une seule ligne.
 */
export function ZoneBanner() {
  const { state } = useGame();
  const { zone } = state;
  const [expanded, setExpanded] = useState(true);
  const name = zone.type === 'pvp' ? 'Territoire libre' : zone.label.replace(/^Zone (safe|PvP|PvE)\s*-\s*/i, '');

  useEffect(() => {
    setExpanded(true);
    const timer = window.setTimeout(() => setExpanded(false), EXPANDED_DURATION);
    return () => window.clearTimeout(timer);
  }, [zone.type, zone.label]);

  if (!expanded) {
    return (
      <div className={`zone-banner zone-banner--compact zone-${zone.type}`}>
        <span className="chip cut-s">{TAG[zone.type]}</span>
        <span className="disp zone-banner__compact-name">{name}</span>
      </div>
    );
  }

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
