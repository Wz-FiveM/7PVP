import { fetchNui } from './nui';
import type { Appearance, CameraPreset, CreatorApplyResult } from '../types/appearance';
import type { ActionResult } from '../types/nui';

/** Requêtes du créateur de personnage (voir client/modules/creator/creator.lua). */
export const creatorApi = {
  apply: (appearance: Appearance) => fetchNui<CreatorApplyResult>('creatorApply', appearance, {}),

  camera: (preset: CameraPreset) => fetchNui<void>('creatorCamera', { preset }),

  rotate: (delta: number) => fetchNui<void>('creatorRotate', { delta }),

  save: () => fetchNui<ActionResult>('creatorSave', {}, { ok: true }),

  cancel: () => fetchNui<void>('creatorCancel'),
};
