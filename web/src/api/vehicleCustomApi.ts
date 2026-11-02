import type { VehicleCustomOptions, VehicleCustomProps } from '../types/vehicleCustom';
import { fetchNui } from './nui';

/** Custom d'un véhicule chez le mécanicien (voir client/modules/vehicle/custom.lua). */
export const vehicleCustomApi = {
  /** Essai sur le véhicule ; `options` revient si le type de jantes a changé */
  preview: (props: VehicleCustomProps) => fetchNui<{ options?: VehicleCustomOptions }>('vehicleCustomPreview', props, {}),
  rotate: (delta: number) => fetchNui<unknown>('vehicleCustomRotate', { delta }, {}),
  save: () => fetchNui<{ ok: boolean; message?: string }>('vehicleCustomSave', {}, { ok: true }),
  cancel: () => fetchNui<unknown>('vehicleCustomCancel', {}, {}),
};
