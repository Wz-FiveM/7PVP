import { useEffect, useState, type ReactNode } from 'react';

/** Photo de profil (avatar Discord) ; affiche `fallback` sans URL ou si l'image ne charge pas. */
export function Avatar({ src, fallback }: { src?: string; fallback: ReactNode }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [src]);

  if (!src || failed) return <>{fallback}</>;
  return <img className="avatar-img" src={src} alt="" draggable={false} onError={() => setFailed(true)} />;
}
