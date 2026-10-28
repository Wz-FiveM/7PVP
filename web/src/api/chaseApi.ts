import { fetchNui } from './nui';
import type { ActionResult } from '../types/nui';

/** Course poursuite (voir client/modules/activities/chase.lua). */
export const chaseApi = {
  vote: (model: string) => fetchNui<ActionResult>('chaseVote', { model }, { ok: true, message: 'Vote enregistré (simulé)' }),
};
