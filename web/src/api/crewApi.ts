import { fetchNui } from './nui';
import type { ActionResult } from '../types/nui';
import type { ContainerId, CrewBoardRow, CrewTournamentState, LeaderboardScope } from '../types/game';

const MOCK_OK: ActionResult = { ok: true, message: 'Action simulée (navigateur)' };

const mockCrewBoard: CrewBoardRow[] = [
  { tag: 'MGZ', name: 'Magazine', members: 8, territories: 2, score: 164, kills: 124, deaths: 71, captures: 4 },
  { tag: 'RXN', name: 'Rixe Nord', members: 5, territories: 1, score: 98, kills: 88, deaths: 90, captures: 1 },
  { tag: 'VLT', name: 'Volt', members: 12, territories: 0, score: 41, kills: 41, deaths: 60, captures: 0 },
];

/** Menu Crew (voir client/modules/crew/crew.lua). */
export const crewApi = {
  create: (tag: string, name: string) => fetchNui<ActionResult>('crewCreate', { tag, name }, MOCK_OK),

  invite: (target: number) => fetchNui<ActionResult>('crewInvite', { target }, MOCK_OK),

  respond: (accept: boolean) => fetchNui<ActionResult>('crewRespond', { accept }, MOCK_OK),

  leave: () => fetchNui<ActionResult>('crewLeave', {}, MOCK_OK),

  kick: (key: number) => fetchNui<ActionResult>('crewKick', { key }, MOCK_OK),

  transfer: (key: number) => fetchNui<ActionResult>('crewTransfer', { key }, MOCK_OK),

  disband: () => fetchNui<ActionResult>('crewDisband', {}, MOCK_OK),

  warDeclare: (tag: string, stake: number) => fetchNui<ActionResult>('crewWarDeclare', { tag, stake }, MOCK_OK),

  warRespond: (accept: boolean) => fetchNui<ActionResult>('crewWarRespond', { accept }, MOCK_OK),

  tournament: () => fetchNui<CrewTournamentState>('crewTournamentGet', {}, {
    running: false,
    startsIn: 200000,
    endsIn: 201800,
    prize: 50000,
    minCrews: 2,
    crews: [{ tag: 'RXN', name: 'Rixe Nord', kills: 0, mine: false }],
  }),

  tournamentJoin: () => fetchNui<ActionResult>('crewTournamentJoin', {}, MOCK_OK),

  stashPut: (item: string, count: number, from: ContainerId) => fetchNui<ActionResult>('crewStashPut', { item, count, from }, MOCK_OK),

  stashTake: (item: string, count: number, to: 'bag' | 'protected') => fetchNui<ActionResult>('crewStashTake', { item, count, to }, MOCK_OK),

  leaderboard: (scope: LeaderboardScope) =>
    fetchNui<{ rows: CrewBoardRow[]; title: string }>('crewLeaderboard', { scope }, { rows: mockCrewBoard, title: 'Saison novembre 2026' }),
};
