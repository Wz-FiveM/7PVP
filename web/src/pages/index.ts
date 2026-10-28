import type { ComponentType } from 'react';
import type { IconName } from '../components/icons/Icon';
import { HelpPage } from './HelpPage';
import { ContractsPage } from './ContractsPage';
import { CraftingPage } from './CraftingPage';
import { GroupPage } from './GroupPage';
import { InventoryPage } from './InventoryPage';
import { LeaderboardPage } from './LeaderboardPage';
import { ProfilePage } from './ProfilePage';
import { ShopPage } from './ShopPage';

export type PageId = 'inventory' | 'group' | 'crafting' | 'contracts' | 'profile' | 'leaderboard' | 'shop' | 'help';

export interface PageDefinition {
  id: PageId;
  label: string;
  icon: IconName;
  component: ComponentType;
}

/** Pages du menu, dans l'ordre de la barre latérale. */
export const PAGES: PageDefinition[] = [
  { id: 'inventory', label: 'Inventaire', icon: 'inventory', component: InventoryPage },
  { id: 'group', label: 'Groupe', icon: 'group', component: GroupPage },
  { id: 'crafting', label: 'Fabrication', icon: 'craft', component: CraftingPage },
  { id: 'contracts', label: 'Contrats', icon: 'contract', component: ContractsPage },
  { id: 'profile', label: 'Profil', icon: 'profile', component: ProfilePage },
  { id: 'leaderboard', label: 'Top joueurs', icon: 'leaderboard', component: LeaderboardPage },
  { id: 'shop', label: 'Boutique', icon: 'shop', component: ShopPage },
  { id: 'help', label: 'Aide', icon: 'help', component: HelpPage },
];
