import { useT } from '../../i18n';
import type { ZoneInfo } from '../../types/game';

const SHORT_LABEL: Record<ZoneInfo['type'], string> = { safe: 'Safe', pve: 'PvE', pvp: 'PvP' };

interface ZoneChipProps {
  zone: ZoneInfo;
  /** Affiche aussi le nom de la zone */
  detailed?: boolean;
}

export function ZoneChip({ zone, detailed }: ZoneChipProps) {
  const t = useT();
  // Préfixe « Zone safe - » retiré après traduction (« Safe zone - » en anglais...)
  const name = t(zone.label).replace(/^.*?\s-\s+/, '');
  return (
    <span className={`chip cut-s zone-${zone.type}`}>
      {t(SHORT_LABEL[zone.type])}
      {detailed && zone.type !== 'pvp' && ` · ${name}`}
    </span>
  );
}
