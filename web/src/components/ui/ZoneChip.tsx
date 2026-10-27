import type { ZoneInfo } from '../../types/game';

const SHORT_LABEL: Record<ZoneInfo['type'], string> = { safe: 'Safe', pve: 'PvE', pvp: 'PvP' };

interface ZoneChipProps {
  zone: ZoneInfo;
  /** Affiche aussi le nom de la zone */
  detailed?: boolean;
}

export function ZoneChip({ zone, detailed }: ZoneChipProps) {
  const name = zone.label.replace(/^Zone (safe|PvP|PvE)\s*-\s*/i, '');
  return (
    <span className={`chip cut-s zone-${zone.type}`}>
      {SHORT_LABEL[zone.type]}
      {detailed && zone.type !== 'pvp' && ` · ${name}`}
    </span>
  );
}
