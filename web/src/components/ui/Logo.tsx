import { rem } from '../../utils/scale';

interface LogoProps {
  /** Taille du texte en px à 1080p (mise à l'échelle avec la résolution) */
  size?: number;
}

/** Réticule + « 7PVP » */
export function Logo({ size = 26 }: LogoProps) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: rem(size * 0.4) }}>
      <svg
        style={{ width: rem(size * 1.1), height: rem(size * 1.1) }}
        viewBox="0 0 64 64"
        fill="none"
        stroke="var(--hazard)"
        strokeWidth={5}
        aria-hidden="true"
      >
        <circle cx="32" cy="32" r="20" />
        <path d="M32 2v16M32 46v16M2 32h16M46 32h16" />
      </svg>
      <span className="disp" style={{ fontSize: rem(size), fontWeight: 700, lineHeight: 1 }}>
        7PVP
      </span>
    </span>
  );
}
