import { useState } from 'react';
import { rem } from '../../utils/scale';

interface LogoProps {
  /** Hauteur en px à 1080p (mise à l'échelle avec la résolution) */
  size?: number;
}

/** Logo 7PVP (web/public/brand/logo.png). Repli texte si l'image est absente. */
export function Logo({ size = 48 }: LogoProps) {
  const [missing, setMissing] = useState(false);

  if (missing) {
    return (
      <span className="disp" style={{ fontSize: rem(size * 0.5), fontWeight: 700, lineHeight: 1, color: 'var(--hazard)' }}>
        7PVP
      </span>
    );
  }

  return (
    <img
      src="./brand/logo.png"
      alt="7PVP"
      draggable={false}
      style={{ height: rem(size), width: 'auto', display: 'block' }}
      onError={() => setMissing(true)}
    />
  );
}
