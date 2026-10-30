import { useId, type ReactNode } from 'react';

interface MedalTier {
  /** Dégradé du cadre, du haut vers le bas */
  frame: [string, string, string];
  /** Lueur au fond du médaillon */
  glow: string;
  /** Nombre de losanges sous le médaillon */
  pips: number;
}

const GOLD: MedalTier['frame'] = ['#fff1a8', '#d9a02a', '#7d5210'];
const TIERS: Record<string, MedalTier> = {
  double: { frame: ['#f4f6f8', '#9aa4ad', '#4b535b'], glow: '#3f6d8c', pips: 2 },
  triple: { frame: GOLD, glow: '#7a2020', pips: 3 },
  fury: { frame: GOLD, glow: '#c2560f', pips: 4 },
  frenzy: { frame: ['#ffb199', '#c8321f', '#5e0d08'], glow: '#d0301c', pips: 5 },
  massacre: { frame: ['#ffe27a', '#a11d12', '#1b0605'], glow: '#ff3b1f', pips: 6 },
  first_blood: { frame: GOLD, glow: '#8c1414', pips: 0 },
  revenge: { frame: ['#f4f6f8', '#9aa4ad', '#4b535b'], glow: '#6b2a8c', pips: 0 },
};
const DEFAULT_TIER: MedalTier = { frame: GOLD, glow: '#3a3f46', pips: 0 };

// Hexagone du médaillon et ses quatre fleurons
const HEXAGON = 'M50 10 86 30v40L50 90 14 70V30z';
const FLEURONS = ['M50 3l5 7-5 5-5-7z', 'M92 26l-2 8-7-1 2-8z', 'M92 74l-9-1 2-7 8 1z', 'M8 74l9-1-2-7-8 1z', 'M8 26l2 8 7-1-2-8z'];

/** Grande faucheuse : capuche, crâne, côtes et faux. */
function Reaper() {
  return (
    <>
      <path d="M74 18 70 94" stroke="#7b5a2c" strokeWidth="3" strokeLinecap="round" />
      <path d="M75 17C62 5 39 6 25 19c15-6 33-5 49 8z" fill="#d7dde2" stroke="#59616a" strokeWidth="1" />
      <path d="M50 18C35 18 27 31 27 46c0 18-3 32-8 46h62c-5-14-8-28-8-46 0-15-8-28-23-28z" fill="#131318" stroke="#40404a" strokeWidth="1.4" />
      <path d="M50 26c-10 0-16 8-16 18 0 11 7 22 16 22s16-11 16-22c0-10-6-18-16-18z" fill="#050507" />
      <path d="M50 29c-8 0-13 6-13 14 0 5 2 8 5 10v5h16v-5c3-2 5-5 5-10 0-8-5-14-13-14z" fill="#ece7d6" />
      <ellipse cx="44.5" cy="43" rx="3.8" ry="4.4" fill="#0b0b0d" />
      <ellipse cx="55.5" cy="43" rx="3.8" ry="4.4" fill="#0b0b0d" />
      <path d="M50 47l-2.2 4.2h4.4z" fill="#0b0b0d" />
      <path d="M45.5 53.5v4.5M48.5 53.5v4.5M51.5 53.5v4.5M54.5 53.5v4.5" stroke="#0b0b0d" strokeWidth="0.9" />
      <path d="M41 68c6 3 12 3 18 0M39 74c7 4 15 4 22 0M38 80c8 4 16 4 24 0" fill="none" stroke="#d8d2bf" strokeWidth="2.2" strokeLinecap="round" />
      <path d="M50 64v22" stroke="#d8d2bf" strokeWidth="2.2" strokeLinecap="round" />
    </>
  );
}

/** Goutte de sang et poignard. */
function FirstBlood() {
  return (
    <>
      <path d="M30 20 66 62l-4 4-36-42z" fill="#d7dde2" stroke="#59616a" strokeWidth="1" />
      <path d="M58 70 72 56l3 3-14 14z" fill="#d9a02a" />
      <path d="m68 69 10 10-4 4-10-10z" fill="#3a2a16" />
      <path d="M41 42c9 11 13 18 13 25a13 13 0 0 1-26 0c0-7 4-14 13-25z" fill="#c8141c" stroke="#5e0508" strokeWidth="1.4" />
      <path d="M34 66c0 4 2 7 5 8" fill="none" stroke="#ff8f8f" strokeWidth="2" strokeLinecap="round" />
    </>
  );
}

/** Crâne sur deux épées croisées. */
function Revenge() {
  return (
    <>
      <g fill="#d7dde2" stroke="#59616a" strokeWidth="1">
        <path d="M22 18 76 72l-4 4-54-54z" />
        <path d="M78 18 24 72l4 4 54-54z" />
      </g>
      <path d="M66 76l10-10 3 3-10 10zM34 76 24 66l-3 3 10 10z" fill="#d9a02a" />
      <path d="M50 28c-10 0-16 7-16 16 0 6 2 10 6 12v7h20v-7c4-2 6-6 6-12 0-9-6-16-16-16z" fill="#ece7d6" stroke="#2b2b30" strokeWidth="1.2" />
      <ellipse cx="43" cy="44" rx="4.6" ry="5.2" fill="#0b0b0d" />
      <ellipse cx="57" cy="44" rx="4.6" ry="5.2" fill="#0b0b0d" />
      <path d="M50 49l-2.6 5h5.2z" fill="#0b0b0d" />
      <path d="M44.5 57v5M48.2 57v5M51.8 57v5M55.5 57v5" stroke="#0b0b0d" strokeWidth="1" />
    </>
  );
}

function pictureFor(id: string): ReactNode {
  if (id === 'first_blood') return <FirstBlood />;
  if (id === 'revenge') return <Revenge />;
  return <Reaper />;
}

/** Cadre de médaille ; sans contenu, le fond reste vide pour y poser une icône. */
export function CodMedalFrame({ tier = DEFAULT_TIER, children }: { tier?: MedalTier; children?: ReactNode }) {
  const uid = useId();
  const frameId = `${uid}-frame`;
  const glowId = `${uid}-glow`;
  const pipStart = 50 - ((tier.pips - 1) * 7) / 2;
  return (
    <svg className="cod-medal__art" viewBox="0 0 100 100" aria-hidden="true">
      <defs>
        <linearGradient id={frameId} x1="0" y1="0" x2="0.3" y2="1">
          <stop offset="0" stopColor={tier.frame[0]} />
          <stop offset="0.5" stopColor={tier.frame[1]} />
          <stop offset="0.72" stopColor={tier.frame[2]} />
          <stop offset="1" stopColor={tier.frame[0]} />
        </linearGradient>
        <radialGradient id={glowId} cx="0.5" cy="0.45" r="0.62">
          <stop offset="0" stopColor={tier.glow} />
          <stop offset="1" stopColor="#08080a" />
        </radialGradient>
      </defs>
      <path d={HEXAGON} fill={`url(#${glowId})`} stroke={`url(#${frameId})`} strokeWidth="5" strokeLinejoin="round" />
      <path d={HEXAGON} fill="none" stroke="rgba(0, 0, 0, 0.55)" strokeWidth="0.8" transform="translate(50 50) scale(0.88) translate(-50 -50)" />
      {children}
      {FLEURONS.map((path) => <path key={path} d={path} fill={`url(#${frameId})`} stroke="rgba(0, 0, 0, 0.5)" strokeWidth="0.6" />)}
      {Array.from({ length: tier.pips }, (_, index) => (
        <path
          key={index}
          d={`M${pipStart + index * 7} 90l2.8 3.6-2.8 3.6-2.8-3.6z`}
          fill={tier.frame[0]}
          stroke="rgba(0, 0, 0, 0.7)"
          strokeWidth="0.6"
        />
      ))}
    </svg>
  );
}

/** Médaille dessinée d'un exploit (multi-kill, premier sang, revanche). */
export function CodMedal({ id }: { id: string }) {
  return <CodMedalFrame tier={TIERS[id]}>{pictureFor(id)}</CodMedalFrame>;
}
