import type { ComponentType } from 'react';
import type { IconName } from '../components/icons/Icon';
import { CasesPage } from './CasesPage';
import { HelpPage } from './HelpPage';
import { ContractsPage } from './ContractsPage';
import { CraftingPage } from './CraftingPage';
import { GroupPage } from './GroupPage';
import { InventoryPage } from './InventoryPage';
import { MarketPage } from './MarketPage';
import { LeaderboardPage } from './LeaderboardPage';
import { ProfilePage } from './ProfilePage';
import { ShopPage } from './ShopPage';

export type PageId = 'inventory' | 'group' | 'crafting' | 'contracts' | 'market' | 'profile' | 'leaderboard' | 'shop' | 'cases' | 'help';

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
  { id: 'group', label: 'Équipe', icon: 'group', component: GroupPage },
  { id: 'crafting', label: 'Fabrication', icon: 'craft', component: CraftingPage, npcOnly: true },
  { id: 'contracts', label: 'Contrats', icon: 'contract', component: ContractsPage, npcOnly: true },
  { id: 'market', label: 'Place de marché', icon: 'shop', component: MarketPage, npcOnly: true },
  { id: 'profile', label: 'Profil', icon: 'profile', component: ProfilePage },
  { id: 'leaderboard', label: 'Top joueurs', icon: 'leaderboard', component: LeaderboardPage },
  { id: 'shop', label: 'Boutique', icon: 'shop', component: ShopPage },
  { id: 'cases', label: 'Caisses', icon: 'crate', component: CasesPage },
  { id: 'help', label: 'Aide', icon: 'help', component: HelpPage },
];
