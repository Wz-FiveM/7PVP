import type { EloChange } from '../../types/game';

/** Nouvelle cote ELO et son changement, sous le résultat d'une partie (course, CVC, 1VS1). */
export function EloDelta({ elo }: { elo: EloChange }) {
  return (
    <span className="mono chase-banner__elo">
      ELO {elo.after}
      <span className={elo.delta >= 0 ? 'chase-banner__delta--up' : 'chase-banner__delta--down'}>
        {elo.delta >= 0 ? `+${elo.delta}` : elo.delta}
      </span>
    </span>
  );
}
