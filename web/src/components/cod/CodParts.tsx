import { useEffect, useState, type ReactNode } from 'react';
import { t } from '../../i18n';
import type { CodProfile } from '../../types/cod';

export const formatTime = (seconds: number) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

const formatBoostTime = (minutes: number) => (minutes < 60 ? `${minutes} min` : `${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, '0')}`);

/** Temps restant, recalculé à partir du dernier chiffre reçu. */
export function useSecondsLeft(total: number, at: number): number {
  const [now, setNow] = useState(Date.now);
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 200);
    return () => window.clearInterval(timer);
  }, [at]);
  return Math.max(0, Math.ceil(total - (now - at) / 1000));
}

/** Insigne d'un niveau de Prestige : le même dessin que l'emblème de la carte de joueur. */
export const prestigeUrl = (level: number) => `./cod/emblems/prestige${level}.svg`;

/** Débloqué au rang actuel, ou gardé pour toujours avec un jeton de Prestige. */
export const isUnlocked = (id: string | false, rank: number, profile: CodProfile) =>
  rank <= profile.rank || (id !== false && profile.permanent.includes(id));

/** Emblème de rang : écusson à chevrons qui se remplit tous les 10 rangs, ou insigne de Prestige avec le rang en dessous. */
export function RankBadge({ rank, prestige = 0, size = 56 }: { rank: number; prestige?: number; size?: number }) {
  if (prestige > 0) {
    return (
      <span className="cod-badge cod-badge--prestige" style={{ width: size, height: size }} aria-label={t('Prestige {level}, rang {rank}', { level: prestige, rank })}>
        <img src={prestigeUrl(prestige)} alt="" draggable={false} />
        <span className="cod-badge__level" style={{ fontSize: Math.max(10, size * 0.24) }}>{rank}</span>
      </span>
    );
  }
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

/** Rang en petit dans les tableaux, précédé de l'insigne de Prestige s'il y en a un. */
export function RankCell({ rank, prestige }: { rank: number; prestige: number }) {
  return (
    <span className="cod-rankcell">
      {prestige > 0 && <img src={prestigeUrl(prestige)} alt={t('Prestige {level}', { level: prestige })} draggable={false} />}
      {rank}
    </span>
  );
}

/** Pseudo, progression et emblème (en haut à droite des menus). */
export function CodOperator({ profile }: { profile: CodProfile }) {
  const progress = profile.xpNeeded > 0 ? (profile.xpInto / profile.xpNeeded) * 100 : 100;
  return (
    <div className="cod-menu__operator">
      <div className="cod-menu__operator-text">
        <span className="cod-menu__operator-name">{profile.name}</span>
        <span className="cod-xpbar"><span style={{ width: `${progress}%` }} /></span>
        <span className="cod-menu__operator-xp">
          {profile.canPrestige
            ? t('PRESTIGE DISPONIBLE')
            : profile.xpNeeded > 0 ? `${profile.xpInto} / ${profile.xpNeeded} XP` : t('RANG MAXIMUM')}
        </span>
        {profile.xpBoost && (
          <span className="cod-menu__boost">
            {t('XP ×{factor} · encore {time}', { factor: profile.xpBoost.factor, time: formatBoostTime(profile.xpBoost.minutes) })}
          </span>
        )}
      </div>
      <RankBadge rank={profile.rank} prestige={profile.prestige} size={52} />
    </div>
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
