import type { CreatorPayload } from './appearance';
import type {
  GameConfig, KillfeedEntry, LobbyMode, MinimapAnchor, PlayerState, ToastKind, Vitals, ZoneInfo,
} from './game';

/** Messages envoyés par Lua via `Nui.send(action, data)` */
export type NuiMessage =
  | { action: 'sync'; data: PlayerState }
  | { action: 'zone'; data: ZoneInfo }
  | { action: 'vitals'; data: Vitals }
  | { action: 'hotbar'; data: { visible: boolean } }
  | { action: 'minimap'; data: MinimapAnchor }
  | { action: 'lobby'; data: { open: boolean; modes?: LobbyMode[] } }
  /** mode de jeu en cours, `false` au lobby */
  | { action: 'mode'; data: { mode: string | false } }
  | { action: 'creator'; data: CreatorPayload }
  | { action: 'menu'; data: { open: boolean; inSafe: boolean } }
  | { action: 'notify'; data: { text: string; kind: ToastKind } }
  | { action: 'killfeed'; data: KillfeedEntry }
  | { action: 'death'; data: { seconds: number } }
  | { action: 'alive'; data?: undefined };

/** Réponse du callback NUI `ready` */
export interface InitPayload {
  config: GameConfig;
  player?: PlayerState;
  zone: ZoneInfo;
}

/** Réponse des actions (achat, utilisation d'objet) */
export interface ActionResult {
  ok: boolean;
  message?: string;
}
