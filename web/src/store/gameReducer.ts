import type {
  CaseSpin,
  ChatMessage,
  GameConfig,
  GroupData,
  GroupInvite,
  GroupVital,
  LootContainer,
  PauseInfo,
  DeathRecap,
  BountyEntry,
  GameClock,
  HordeState,
  ControlZoneHud,
  FreeroamState,
  NearServices,
  HelpNotification,
  InteractionItem,
  KillfeedItem,
  LeaderboardRow,
  LobbyMode,
  PlayerState,
  MinimapAnchor,
  Toast,
  TradeData,
  Vitals,
  ZoneInfo,
} from '../types/game';
import type { AdminSelf, AdminToggle, NoclipInfo, NoclipKeyId } from '../types/admin';
import type { InitPayload } from '../types/nui';

/** Nombre de messages du chat gardés en mémoire */
const CHAT_HISTORY = 60;

export interface GameState {
  ready: boolean;
  config: GameConfig;
  player: PlayerState | null;
  zone: ZoneInfo;
  vitals: Vitals;
  /** Barre de raccourcis du HUD (TAB maintenu) */
  hotbarVisible: boolean;
  /** Position de la minimap GTA (null tant que le jeu ne l'a pas envoyée) */
  minimap: MinimapAnchor | null;
  /** Mode de jeu en cours ('pvp', 'freeroam'), null au lobby */
  mode: string | null;
  lobby: { open: boolean; modes: LobbyMode[] };
  chat: { open: boolean; messages: ChatMessage[] };
  admin: { open: boolean; self: AdminSelf };
  /** Aide à l'écran du noclip et touches maintenues */
  noclip: NoclipInfo & { held: NoclipKeyId[] };
  /** `near` : PNJ de service à portée ; `page` : page demandée en parlant à un PNJ */
  menu: { open: boolean; inSafe: boolean; near: NearServices; page: string | null; key: number };
  death: { active: boolean; seconds: number; key: number; recap: DeathRecap };
  /** Primes en cours sur le serveur */
  bounties: BountyEntry[];
  clock: GameClock | null;
  /** Horde en cours ; `endsAt` en Date.now() */
  horde: (HordeState & { endsAt: number }) | null;
  /** Fin du statut « en combat » (Date.now()), 0 = hors combat */
  combatUntil: number;
  /** Groupe du joueur, invitation reçue et vie des coéquipiers */
  group: GroupData | null;
  groupInvite: GroupInvite | null;
  groupVitals: GroupVital[];
  /** Menu pause (Échap) */
  pause: { open: boolean; info: PauseInfo | null };
  toasts: Toast[];
  killfeed: KillfeedItem[];
  leaderboard: LeaderboardRow[];
  leaderboardTitle: string;
  /** Zone de contrôle où se trouve le joueur */
  controlZone: ControlZoneHud | null;
  freeroam: FreeroamState;
  /** Aide affichée (touche + action), null si aucune */
  helpNotify: HelpNotification | null;
  /** Menu d'interaction : `items` null pendant le ciblage (avant le clic sur une cible) */
  interaction: { open: boolean; items: InteractionItem[] | null };
  /** Butin ouvert à droite de l'inventaire (largage), null sinon */
  loot: LootContainer | null;
  /** Échange en cours avec un autre joueur (à droite de l'inventaire), null sinon */
  trade: TradeData | null;
  /** Roulette d'ouverture de caisse affichée par-dessus le menu, null sinon */
  caseSpin: CaseSpin | null;
}

export type GameAction =
  | { type: 'init'; payload: InitPayload }
  | { type: 'sync'; player: PlayerState }
  | { type: 'zone'; zone: ZoneInfo }
  | { type: 'vitals'; vitals: Vitals }
  | { type: 'hotbar'; visible: boolean }
  | { type: 'minimap'; minimap: MinimapAnchor }
  | { type: 'mode'; mode: string | null }
  | { type: 'lobby'; open: boolean; modes?: LobbyMode[] }
  | { type: 'chat/open'; open: boolean }
  | { type: 'chat/message'; message: ChatMessage }
  | { type: 'admin'; open: boolean; self?: AdminSelf }
  /** Navigateur uniquement : simule une option admin activée / coupée */
  | { type: 'admin/toggle'; key: AdminToggle }
  | { type: 'noclip'; info: NoclipInfo }
  | { type: 'noclip/held'; held: NoclipKeyId[] }
  | { type: 'menu'; open: boolean; inSafe: boolean; near?: NearServices; page?: string }
  | { type: 'death'; seconds: number; recap?: DeathRecap }
  | { type: 'bounties'; list: BountyEntry[] }
  | { type: 'clock'; clock: GameClock }
  | { type: 'horde'; horde: HordeState | null }
  | { type: 'alive' }
  | { type: 'combat'; seconds: number }
  | { type: 'group'; group: GroupData | null }
  | { type: 'group/invite'; invite: GroupInvite | null }
  | { type: 'group/vitals'; vitals: GroupVital[] }
  | { type: 'pause'; open: boolean; info?: PauseInfo }
  | { type: 'toast/add'; toast: Toast }
  | { type: 'toast/remove'; id: number }
  | { type: 'killfeed/add'; item: KillfeedItem }
  | { type: 'killfeed/remove'; id: number }
  | { type: 'leaderboard'; rows: LeaderboardRow[]; title: string }
  | { type: 'controlZone'; zone: ControlZoneHud | null }
  | { type: 'freeroam'; patch: Partial<FreeroamState> }
  | { type: 'helpNotify'; help: HelpNotification | null }
  | { type: 'interaction'; open: boolean; items: InteractionItem[] | null }
  | { type: 'loot'; loot: LootContainer | null; items?: LootContainer['items'] }
  | { type: 'trade'; trade: TradeData | null }
  | { type: 'case/spin'; spin: Omit<CaseSpin, 'key'> }
  | { type: 'case/close' };

export const initialState: GameState = {
  ready: false,
  config: {
    shop: [],
    items: {},
    containers: {
      bag: { label: 'Sac', capacity: 0 },
      protected: { label: 'Conteneur protégé', capacity: 0 },
      stash: { label: 'Coffre 1', capacity: 0, safeOnly: true, order: 1 },
    },
    shortcutSlots: 7,
    xpPerLevel: 1000,
  },
  player: null,
  zone: { label: 'Zone PvP', type: 'pvp' },
  vitals: { health: 100, maxHealth: 100, armor: 0, weapon: false, clip: 0, reserve: 0 },
  hotbarVisible: false,
  minimap: null,
  mode: null,
  lobby: { open: false, modes: [] },
  chat: { open: false, messages: [] },
  admin: { open: false, self: { noclip: false, god: false, invisible: false, spectating: false } },
  noclip: { active: false, toggleKey: 'F11', speed: 0, fastMultiplier: 1, slowMultiplier: 1, held: [] },
  menu: { open: false, inSafe: false, near: {}, page: null, key: 0 },
  death: { active: false, seconds: 0, key: 0, recap: {} },
  bounties: [],
  clock: null,
  horde: null,
  combatUntil: 0,
  group: null,
  groupInvite: null,
  groupVitals: [],
  pause: { open: false, info: null },
  toasts: [],
  killfeed: [],
  leaderboard: [],
  leaderboardTitle: '',
  controlZone: null,
  freeroam: { menuOpen: false, pvp: false, weapons: [], vehicles: [] },
  helpNotify: null,
  interaction: { open: false, items: null },
  loot: null,
  trade: null,
  caseSpin: null,
};

export function gameReducer(state: GameState, action: GameAction): GameState {
  switch (action.type) {
    case 'init':
      return {
        ...state,
        ready: true,
        config: action.payload.config,
        player: action.payload.player ?? state.player,
        zone: action.payload.zone,
        mode: action.payload.mode === undefined ? state.mode : action.payload.mode || null,
        lobby: action.payload.lobby ?? state.lobby,
      };
    case 'sync':
      return { ...state, player: action.player };
    case 'zone':
      return { ...state, zone: action.zone };
    case 'vitals':
      return { ...state, vitals: action.vitals };
    case 'hotbar':
      return { ...state, hotbarVisible: action.visible };
    case 'minimap':
      return { ...state, minimap: action.minimap };
    case 'mode':
      return { ...state, mode: action.mode };
    case 'admin':
      return { ...state, admin: { open: action.open, self: action.self ?? state.admin.self } };
    case 'admin/toggle':
      return {
        ...state,
        admin: { ...state.admin, self: { ...state.admin.self, [action.key]: !state.admin.self[action.key] } },
      };
    case 'noclip':
      return {
        ...state,
        noclip: { ...action.info, held: [] },
        admin: { ...state.admin, self: { ...state.admin.self, noclip: action.info.active } },
      };
    case 'noclip/held':
      return { ...state, noclip: { ...state.noclip, held: action.held } };
    case 'chat/open':
      return { ...state, chat: { ...state.chat, open: action.open } };
    case 'chat/message':
      return {
        ...state,
        chat: { ...state.chat, messages: [...state.chat.messages, action.message].slice(-CHAT_HISTORY) },
      };
    case 'lobby':
      return {
        ...state,
        lobby: { open: action.open, modes: action.modes ?? state.lobby.modes },
        menu: action.open ? { ...state.menu, open: false } : state.menu,
      };
    case 'menu':
      return {
        ...state,
        menu: {
          open: action.open,
          inSafe: action.inSafe,
          near: action.near ?? {},
          page: action.page ?? null,
          key: state.menu.key + 1,
        },
        // La récompense est déjà donnée par le serveur : fermer le menu ne fait que cacher la roulette
        caseSpin: action.open ? state.caseSpin : null,
      };
    case 'death':
      return {
        ...state,
        menu: { ...state.menu, open: false },
        death: { active: true, seconds: action.seconds, key: state.death.key + 1, recap: action.recap ?? {} },
        combatUntil: 0,
        caseSpin: null,
      };
    case 'clock':
      return { ...state, clock: action.clock };
    case 'horde':
      return { ...state, horde: action.horde ? { ...action.horde, endsAt: Date.now() + action.horde.endsIn * 1000 } : null };
    case 'bounties':
      return { ...state, bounties: action.list };
    case 'alive':
      return { ...state, death: { ...state.death, active: false } };
    case 'group':
      return { ...state, group: action.group, groupInvite: action.group ? null : state.groupInvite, groupVitals: [] };
    case 'group/invite':
      return { ...state, groupInvite: action.invite };
    case 'pause':
      return { ...state, pause: { open: action.open, info: action.info ?? state.pause.info } };
    case 'group/vitals':
      return { ...state, groupVitals: action.vitals };
    case 'combat':
      return { ...state, combatUntil: action.seconds > 0 ? Date.now() + action.seconds * 1000 : 0 };
    case 'toast/add':
      return { ...state, toasts: [...state.toasts, action.toast] };
    case 'toast/remove':
      return { ...state, toasts: state.toasts.filter((toast) => toast.id !== action.id) };
    case 'killfeed/add':
      return { ...state, killfeed: [action.item, ...state.killfeed].slice(0, 6) };
    case 'killfeed/remove':
      return { ...state, killfeed: state.killfeed.filter((item) => item.id !== action.id) };
    case 'leaderboard':
      return { ...state, leaderboard: action.rows, leaderboardTitle: action.title };
    case 'interaction':
      return { ...state, interaction: { open: action.open, items: action.open ? action.items : null } };
    case 'helpNotify':
      return { ...state, helpNotify: action.help };
    case 'loot':
      // Mise à jour du contenu seul (quelqu'un a pris un objet) : on garde le nom du butin
      if (!action.loot && action.items && state.loot) return { ...state, loot: { ...state.loot, items: action.items } };
      return { ...state, loot: action.loot };
    case 'trade':
      return { ...state, trade: action.trade };
    case 'case/spin':
      return { ...state, caseSpin: { ...action.spin, key: (state.caseSpin?.key ?? 0) + 1 } };
    case 'case/close':
      return { ...state, caseSpin: null };
    case 'freeroam':
      return { ...state, freeroam: { ...state.freeroam, ...action.patch } };
    case 'controlZone':
      return { ...state, controlZone: action.zone };
  }
}
