import type { ItemType } from '../../types/game';

export type IconName = ItemType | 'knife' | 'armor' | 'bandage' | 'lock' | 'check' | 'crosshair';

/** Icônes au trait (viewBox 24x24), dans le style de la D.A Frontline. */
const PATHS: Record<IconName, string> = {
  weapon: 'M1 10h17l1-2h4v3h-3l-1 1h-5l-1 2h-3l-1 4H6l1-4H4l-1-2H1z',
  knife: 'M2 15l13-8 6-1-4 5-12 6zM5 17l-2 3',
  ammo: 'M5 9a2 2 0 0 1 4 0v11H5zM10 9a2 2 0 0 1 4 0v11h-4zM15 9a2 2 0 0 1 4 0v11h-4z',
  consumable: 'M3 7h18v13H3zM9 7V4h6v3M12 10v6M9 13h6',
  bandage: 'M4 9l5-5 11 11-5 5zM9 11l1 1M12 14l1 1M11 9l1 1M14 12l1 1',
  armor: 'M8 3h8l1 3 3 2v13H4V8l3-2zM9 3c0 3 6 3 6 0M4 13h16',
  money: 'M2 7h20v10H2zM14.5 12a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0z',
  lock: 'M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4',
  check: 'M4 12l5 5L20 6',
  crosshair: 'M12 2v6M12 16v6M2 12h6M16 12h6M18 12a6 6 0 1 1-12 0 6 6 0 0 1 12 0z',
};

interface IconProps {
  name: IconName;
  className?: string;
  size?: number;
  strokeWidth?: number;
}

export function Icon({ name, className, size = 24, strokeWidth = 1.5 }: IconProps) {
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinejoin="round"
      strokeLinecap="round"
      aria-hidden="true"
    >
      <path d={PATHS[name]} />
    </svg>
  );
}

/** Icône de repli d'un objet sans image. */
export function itemIconName(name: string, type: ItemType): IconName {
  if (name === 'weapon_knife') return 'knife';
  if (name === 'armor') return 'armor';
  if (name === 'bandage') return 'bandage';
  return type;
}
