import type { ItemType } from '../../types/game';
import { rem } from '../../utils/scale';

export type IconName =
  | ItemType
  | 'knife'
  | 'armor'
  | 'bandage'
  | 'lock'
  | 'check'
  | 'crosshair'
  | 'inventory'
  | 'profile'
  | 'leaderboard'
  | 'shop'
  | 'help'
  | 'exit'
  | 'group'
  | 'craft'
  | 'contract'
  | 'crate'
  | 'flag'
  | 'trophy'
  | 'moon';

/** Icônes au trait (viewBox 24x24), dans le style de la D.A Frontline. */
const PATHS: Record<IconName, string> = {
  weapon: 'M1 10h17l1-2h4v3h-3l-1 1h-5l-1 2h-3l-1 4H6l1-4H4l-1-2H1z',
  knife: 'M2 15l13-8 6-1-4 5-12 6zM5 17l-2 3',
  ammo: 'M5 9a2 2 0 0 1 4 0v11H5zM10 9a2 2 0 0 1 4 0v11h-4zM15 9a2 2 0 0 1 4 0v11h-4z',
  consumable: 'M3 7h18v13H3zM9 7V4h6v3M12 10v6M9 13h6',
  bandage: 'M4 9l5-5 11 11-5 5zM9 11l1 1M12 14l1 1M11 9l1 1M14 12l1 1',
  armor: 'M8 3h8l1 3 3 2v13H4V8l3-2zM9 3c0 3 6 3 6 0M4 13h16',
  money: 'M2 7h20v10H2zM14.5 12a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0z',
  attachment: 'M3 10h12v4H3zM15 11h6v2h-6M6 10V7h3v3M11 14v3',
  material: 'M4 8l8-4 8 4-8 4zM4 8v8l8 4 8-4V8M12 12v8',
  vehicle: 'M3 13l2-5h14l2 5v5H3zM3 13h18M7 18v2M17 18v2M6.5 15.5h1M16.5 15.5h1',
  lock: 'M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4',
  check: 'M4 12l5 5L20 6',
  crosshair: 'M12 2v6M12 16v6M2 12h6M16 12h6M18 12a6 6 0 1 1-12 0 6 6 0 0 1 12 0z',
  inventory: 'M5 8h14v12H5zM9 8V5h6v3M5 13h14M11 13v2h2v-2',
  profile: 'M16 8a4 4 0 1 1-8 0 4 4 0 0 1 8 0zM4 21c0-4 3.6-6 8-6s8 2 8 6',
  leaderboard: 'M4 20V12h4v8M10 20V6h4v14M16 20v-6h4v6',
  shop: 'M3 4h2l2 11h11l2-8H6.5M9 20h.01M17 20h.01',
  help: 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0zM12 11v6M12 7h.01',
  exit: 'M10 4H5v16h5M14 8l4 4-4 4M18 12H9',
  group: 'M12 8a3 3 0 1 1-6 0 3 3 0 0 1 6 0zM2 20c0-3.5 2.7-5.5 7-5.5s7 2 7 5.5M16 5a3 3 0 0 1 0 6M18 14.5c2.4.6 4 2.3 4 5.5',
  craft: 'M14 4l6 6-3 3-6-6zM11 7l-8 8 3 3 8-8M3 21h8',
  contract: 'M6 3h12v18H6zM9 3v3h6V3M9 11h6M9 15h4',
  crate: 'M3 7l9-4 9 4v10l-9 4-9-4zM3 7l9 4 9-4M12 11v10',
  flag: 'M5 21V3M5 4h12l-2 4 2 4H5',
  trophy: 'M7 4h10v5a5 5 0 0 1-10 0zM7 6H3c0 3 2 5 4 5M17 6h4c0 3-2 5-4 5M12 14v4M8 21h8',
  moon: 'M20 14a8 8 0 1 1-10-10 7 7 0 0 0 10 10z',
};

interface IconProps {
  name: IconName;
  className?: string;
  /** Taille en px à 1080p (mise à l'échelle avec la résolution) */
  size?: number;
  strokeWidth?: number;
}

export function Icon({ name, className, size = 24, strokeWidth = 1.5 }: IconProps) {
  return (
    <svg
      className={className}
      style={{ width: rem(size), height: rem(size), flex: 'none' }}
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
