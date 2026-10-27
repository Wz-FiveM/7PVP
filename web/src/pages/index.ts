import type { ComponentType } from 'react';
import { HelpPage } from './HelpPage';
import { InventoryPage } from './InventoryPage';
import { LeaderboardPage } from './LeaderboardPage';
import { ProfilePage } from './ProfilePage';
import { ShopPage } from './ShopPage';

export type PageId = 'inventory' | 'profile' | 'leaderboard' | 'shop' | 'help';

export interface PageDefinition {
  id: PageId;
  label: string;
  component: ComponentType;
}

/** Onglets du menu, dans l'ordre de la barre du haut. */
export const PAGES: PageDefinition[] = [
  { id: 'inventory', label: 'Inventaire', component: InventoryPage },
  { id: 'profile', label: 'Profil', component: ProfilePage },
  { id: 'leaderboard', label: 'Classement', component: LeaderboardPage },
  { id: 'shop', label: 'Boutique', component: ShopPage },
  { id: 'help', label: 'Aide', component: HelpPage },
];
