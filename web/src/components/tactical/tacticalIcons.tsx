/** Pictogrammes du mode Sabotage : un par rôle et un par capacité (traits simples, couleur du texte). */

const ROLE_PATHS: Record<string, string[]> = {
  // œil : repère les ennemis
  scout: ['M2 12s3.8-7 10-7 10 7 10 7-3.8 7-10 7S2 12 2 12z', 'M12 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6z'],
  // nuage : fumées
  smoker: ['M7 18h10a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.2 11.3 3.4 3.4 0 0 0 7 18z'],
  // bouclier : tient un site
  warden: ['M12 3l8 3v6c0 4.8-3.4 8-8 9-4.6-1-8-4.2-8-9V6z', 'M12 7v10'],
  // croix : soigne
  medic: ['M9 3h6v6h6v6h-6v6H9v-6H3V9h6z'],
};

const ABILITY_PATHS: Record<string, string[]> = {
  sensor: ['M12 10.5a1.5 1.5 0 1 0 0 3 1.5 1.5 0 1 0 0-3z', 'M8.2 8.2a5.4 5.4 0 0 0 0 7.6', 'M15.8 8.2a5.4 5.4 0 0 1 0 7.6', 'M5.3 5.3a9.5 9.5 0 0 0 0 13.4', 'M18.7 5.3a9.5 9.5 0 0 1 0 13.4'],
  sprint: ['M4 6l6 6-6 6', 'M12 6l6 6-6 6'],
  scan: ['M12 3a9 9 0 1 0 0 18 9 9 0 1 0 0-18z', 'M12 7a5 5 0 1 0 0 10 5 5 0 1 0 0-10z', 'M12 12l6.4-6.4'],
  smoke: ROLE_PATHS.smoker,
  flash: ['M13 2L4 14h7l-1 8 9-12h-7z'],
  curtain: ['M6 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6z', 'M12 8a4 4 0 1 0 0 8 4 4 0 1 0 0-8z', 'M18 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6z'],
  alarm: ['M6 16v-5a6 6 0 0 1 12 0v5l2 2H4z', 'M10 20.5a2 2 0 0 0 4 0'],
  barrier: ['M3 6h18v5H3z', 'M3 13h18v5H3z', 'M9 6v5', 'M15 13v5'],
  lockdown: ['M5 11h14v10H5z', 'M8 11V8a4 4 0 0 1 8 0v3', 'M12 15v2'],
  heal: ['M12 3a9 9 0 1 0 0 18 9 9 0 1 0 0-18z', 'M12 8v8', 'M8 12h8'],
  shield: ROLE_PATHS.warden,
  revive: ['M12 13V4', 'M8 8l4-4 4 4', 'M5 13a7 7 0 0 0 14 0'],
};

function Glyph({ paths, className }: { paths: string[] | undefined; className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      {(paths ?? ['M12 12h.01']).map((path) => <path key={path} d={path} />)}
    </svg>
  );
}

export function RoleIcon({ id, className }: { id: string | undefined; className?: string }) {
  return <Glyph paths={id ? ROLE_PATHS[id] : undefined} className={className} />;
}

export function AbilityIcon({ id, className }: { id: string | undefined; className?: string }) {
  return <Glyph paths={id ? ABILITY_PATHS[id] : undefined} className={className} />;
}
