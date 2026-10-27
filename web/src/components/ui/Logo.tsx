interface LogoProps {
  size?: number;
}

/** Réticule + « 7PVP » */
export function Logo({ size = 26 }: LogoProps) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: size * 0.4 }}>
      <svg width={size * 1.1} height={size * 1.1} viewBox="0 0 64 64" fill="none" stroke="var(--hazard)" strokeWidth={5} aria-hidden="true">
        <circle cx="32" cy="32" r="20" />
        <path d="M32 2v16M32 46v16M2 32h16M46 32h16" />
      </svg>
      <span className="disp" style={{ fontSize: size, fontWeight: 700, lineHeight: 1 }}>
        7PVP
      </span>
    </span>
  );
}
