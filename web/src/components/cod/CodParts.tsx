import { useEffect, useState, type ReactNode } from 'react';
import { t } from '../../i18n';

export const formatTime = (seconds: number) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

/** Temps restant, recalculé à partir du dernier chiffre reçu. */
export function useSecondsLeft(total: number, at: number): number {
  const [now, setNow] = useState(Date.now);
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 200);
    return () => window.clearInterval(timer);
  }, [at]);
  return Math.max(0, Math.ceil(total - (now - at) / 1000));
}

/** Emblème de rang : écusson à chevrons, qui se remplit tous les 10 rangs. */
export function RankBadge({ rank, size = 56 }: { rank: number; size?: number }) {
  const chevrons = Math.min(4, Math.floor(rank / 11) + 1);
  return (
    <svg className="cod-badge" width={size} height={size} viewBox="0 0 64 64" aria-label={t('Rang {rank}', { rank })}>
      <path d="M32 3 L8 15 V36 L32 61 L56 36 V15 Z" className="cod-badge__shield" />
      {Array.from({ length: chevrons }, (_, index) => (
        <path key={index} d={`M16 ${40 - index * 7} L32 ${50 - index * 7} L48 ${40 - index * 7}`} className="cod-badge__chevron" />
      ))}
      <text x="32" y="23" className="cod-badge__rank">{rank}</text>
    </svg>
  );
}

/** Bouton encadré de deux crochets orange. */
export function BracketButton({
  children,
  onClick,
  disabled,
  danger,
}: {
  children: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  danger?: boolean;
}) {
  return (
    <button className={danger ? 'cod-action cod-action--danger' : 'cod-action'} onClick={onClick} disabled={disabled}>
      {children}
    </button>
  );
}

/** Image d'arme (web/public/items/), rien si elle manque. */
export function WeaponImage({ id }: { id: string }) {
  const [missing, setMissing] = useState(false);
  useEffect(() => setMissing(false), [id]);
  if (missing) return null;
  return <img className="cod-weapon" src={`./items/${id.toLowerCase()}.png`} alt="" draggable={false} onError={() => setMissing(true)} />;
}
