import { fetchNui } from './nui';
import type { ActionResult } from '../types/nui';

const MOCK_OK: ActionResult = { ok: true, message: 'Action simulée (navigateur)' };

export interface BountyTarget {
  id: number;
  name: string;
}

/** Primes posées par les joueurs (voir client/modules/combat/bounty.lua). */
export const bountyApi = {
  place: (target: number, amount: number) => fetchNui<ActionResult>('bountyPlace', { target, amount }, MOCK_OK),

  targets: () =>
    fetchNui<{ list: BountyTarget[] }>('bountyTargets', {}, {
      list: [
        { id: 7, name: '[RXN] Bravo' },
        { id: 12, name: 'Kilo' },
      ],
    }),
};
