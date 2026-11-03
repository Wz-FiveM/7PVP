import { useEffect, useState, type ComponentType } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { Icon, type IconName } from '../icons/Icon';
import { CasesTab } from './CasesTab';
import { FreeroamTab } from './FreeroamTab';
import { LootTab } from './LootTab';
import { PlayersTab } from './PlayersTab';
import { PositionsTab } from './PositionsTab';
import { ResaleTab } from './ResaleTab';
import { SelfTab } from './SelfTab';
import { ServerTab } from './ServerTab';
import { ShopTab } from './ShopTab';
import { WeightsTab } from './WeightsTab';
import './admin.css';

interface AdminTab {
  id: string;
  label: string;
  icon: IconName;
  component: ComponentType;
  /** l'onglet a besoin de place (le panneau s'élargit) */
  wide?: boolean;
  /** l'onglet gère lui-même ses marges et son défilement */
  flush?: boolean;
}

/** Onglets du rail, par groupe */
const GROUPS: { label: string; tabs: AdminTab[] }[] = [
  {
    label: 'Joueurs',
    tabs: [
      { id: 'players', label: 'Joueurs', icon: 'group', component: PlayersTab },
      { id: 'self', label: 'Moi', icon: 'profile', component: SelfTab },
      { id: 'server', label: 'Serveur', icon: 'server', component: ServerTab },
    ],
  },
  {
    label: 'Économie',
    tabs: [
      { id: 'shop', label: 'Boutique', icon: 'shop', component: ShopTab, wide: true },
      { id: 'resale', label: 'Revente', icon: 'money', component: ResaleTab, wide: true },
      { id: 'cases', label: 'Caisses', icon: 'case', component: CasesTab, wide: true },
      { id: 'weights', label: 'Poids', icon: 'scale', component: WeightsTab, wide: true },
    ],
  },
  {
    label: 'Monde',
    tabs: [
      { id: 'loot', label: 'Butin', icon: 'crate', component: LootTab, wide: true },
      { id: 'positions', label: 'Positions', icon: 'pin', component: PositionsTab, wide: true, flush: true },
      { id: 'freeroam', label: 'Freeroam', icon: 'flag', component: FreeroamTab, wide: true },
    ],
  },
];
const TABS = GROUPS.flatMap((group) => group.tabs.map((tab) => ({ ...tab, group: group.label })));

/** Dernier onglet ouvert : le panneau est démonté à sa fermeture, et il faut le fermer pour se déplacer */
let rememberedTab = TABS[0].id;

/** Panneau admin (F10) : tiroir à droite pour garder le jeu visible, onglets sur un rail d'icônes. */
export function AdminPanel() {
  const t = useT();
  const { actions } = useGame();
  const [tabId, setTabId] = useState(rememberedTab);
  const tab = TABS.find((entry) => entry.id === tabId) ?? TABS[0];
  const Tab = tab.component;

  useEffect(() => {
    rememberedTab = tabId;
  }, [tabId]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.defaultPrevented) return;
      if (event.key === 'Escape' || event.key === 'F10') actions.closeAdmin();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [actions]);

  return (
    <aside className={tab.wide ? 'admin admin--wide' : 'admin'}>
      <nav className="admin__rail" aria-label={t('Administration')}>
        <span className="admin__badge mono">ADMIN</span>
        {GROUPS.map((group) => (
          <div key={group.label} className="admin__group">
            {group.tabs.map((entry) => (
              <button
                key={entry.id}
                className={entry.id === tab.id ? 'admin__tab admin__tab--active' : 'admin__tab'}
                onClick={() => setTabId(entry.id)}
                aria-label={t(entry.label)}
                aria-current={entry.id === tab.id ? 'page' : undefined}
              >
                <Icon name={entry.icon} size={20} />
                <span className="admin__tip disp">{t(entry.label)}</span>
              </button>
            ))}
          </div>
        ))}
      </nav>
      <section className="admin__main">
        <header className="admin__header">
          <div>
            <span className="admin__kicker mono">{t(tab.group)}</span>
            <h1 className="disp admin__title">{t(tab.label)}</h1>
          </div>
          <button className="admin__close" onClick={actions.closeAdmin} aria-label={t('Fermer')}>
            <span aria-hidden="true">✕</span>
          </button>
        </header>
        <div className={tab.flush ? 'admin__body admin__body--flush' : 'admin__body'}>
          <Tab />
        </div>
      </section>
    </aside>
  );
}
