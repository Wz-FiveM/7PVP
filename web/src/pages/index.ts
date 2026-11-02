import type { ComponentType } from 'react';
import type { IconName } from '../components/icons/Icon';
import { BountiesPage } from './BountiesPage';
import { CasesPage } from './CasesPage';
import { ClassesPage } from './ClassesPage';
import { HelpPage } from './HelpPage';
import { ContractsPage } from './ContractsPage';
import { CraftingPage } from './CraftingPage';
import { CrewPage } from './CrewPage';
import { GroupPage } from './GroupPage';
import { InventoryPage } from './InventoryPage';
import { MarketPage } from './MarketPage';
import { LeaderboardPage } from './LeaderboardPage';
import { ProfilePage } from './ProfilePage';
import { ResalePage } from './ResalePage';
import { ShopPage } from './ShopPage';

export type PageId = 'inventory' | 'class' | 'group' | 'crew' | 'bounties' | 'crafting' | 'contracts' | 'market' | 'resale' | 'profile' | 'leaderboard' | 'shop' | 'cases' | 'help';

export interface PageDefinition {
  id: PageId;
  label: string;
  icon: IconName;
  component: ComponentType;
  /** page d'un PNJ de la zone safe : absente du menu, ouverte en lui parlant */
  npcOnly?: boolean;
}

/** Pages du menu, dans l'ordre de la barre latérale. */
export const PAGES: PageDefinition[] = [
  { id: 'inventory', label: 'Inventaire', icon: 'inventory', component: InventoryPage },
  { id: 'class', label: 'Classe', icon: 'crosshair', component: ClassesPage },
  { id: 'group', label: 'Équipe', icon: 'group', component: GroupPage },
  { id: 'crew', label: 'Crew', icon: 'flag', component: CrewPage },
  { id: 'bounties', label: 'Primes', icon: 'crosshair', component: BountiesPage },
  { id: 'crafting', label: 'Fabrication', icon: 'craft', component: CraftingPage, npcOnly: true },
  { id: 'contracts', label: 'Contrats', icon: 'contract', component: ContractsPage, npcOnly: true },
  { id: 'market', label: 'Place de marché', icon: 'shop', component: MarketPage, npcOnly: true },
  { id: 'resale', label: 'Revente', icon: 'money', component: ResalePage, npcOnly: true },
  { id: 'profile', label: 'Profil', icon: 'profile', component: ProfilePage },
  { id: 'leaderboard', label: 'Top joueurs', icon: 'leaderboard', component: LeaderboardPage },
  { id: 'shop', label: 'Boutique', icon: 'shop', component: ShopPage },
  { id: 'cases', label: 'Caisses', icon: 'crate', component: CasesPage },
  { id: 'help', label: 'Aide', icon: 'help', component: HelpPage },
];
