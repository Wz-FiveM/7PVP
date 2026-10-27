import type { ComponentType } from 'react';
import type { IconName } from '../components/icons/Icon';
import { HelpPage } from './HelpPage';
import { InventoryPage } from './InventoryPage';
import { LeaderboardPage } from './LeaderboardPage';
import { ProfilePage } from './ProfilePage';
import { ShopPage } from './ShopPage';

export type PageId = 'inventory' | 'profile' | 'leaderboard' | 'shop' | 'help';

export interface PageDefinition {
  id: PageId;
  label: string;
  icon: IconName;
  component: ComponentType;
}

/** Pages du menu, dans l'ordre de la barre latérale. */
export const PAGES: PageDefinition[] = [
  { id: 'inventory', label: 'Inventaire', icon: 'inventory', component: InventoryPage },
  { id: 'profile', label: 'Profil', icon: 'profile', component: ProfilePage },
  { id: 'leaderboard', label: 'Top joueurs', icon: 'leaderboard', component: LeaderboardPage },
  { id: 'shop', label: 'Boutique', icon: 'shop', component: ShopPage },
  { id: 'help', label: 'Aide', icon: 'help', component: HelpPage },
];
