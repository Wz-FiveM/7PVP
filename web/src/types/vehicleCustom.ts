/** Custom d'un véhicule (client/modules/vehicle/custom.lua) */
export interface VehicleCustomProps {
  primary: number;
  secondary: number;
  pearl: number;
  wheelColor: number;
  tint: number;
  plate: number;
  wheelType: number;
  /** seulement sur les modèles qui ont des livrées */
  livery?: number;
  neon: boolean;
  /** #RRGGBB */
  neonColor: string;
  xenon: boolean;
  xenonColor: number;
  turbo: boolean;
  /** type de modification GTA -> pièce (-1 : d'origine) */
  mods: Record<string, number>;
}

export type VehicleCustomTab = 'body' | 'wheels' | 'performance';

export interface VehicleCustomMod {
  id: string;
  label: string;
  tab: VehicleCustomTab;
  /** noms des pièces ; le premier est la pièce d'origine (index -1 de GTA) */
  options: string[];
}

/** Ce que le modèle permet */
export interface VehicleCustomOptions {
  mods: VehicleCustomMod[];
  isCar: boolean;
  liveries: number;
  performance: boolean;
}

export interface VehicleCustomChoice {
  id: number;
  label: string;
}

export interface VehicleCustomColor {
  /** couleur GTA (absente pour les néons : la couleur est directement `hex`) */
  id?: number;
  label: string;
  hex: string;
}

export interface VehicleCustomPalettes {
  colors: VehicleCustomColor[];
  neonColors: VehicleCustomColor[];
  xenonColors: VehicleCustomColor[];
  tints: VehicleCustomChoice[];
  plates: VehicleCustomChoice[];
  wheelTypes: VehicleCustomChoice[];
}

export type VehicleCustomPayload =
  | { open: false }
  | {
      open: true;
      label: string;
      props: VehicleCustomProps;
      options: VehicleCustomOptions;
      palettes: VehicleCustomPalettes;
    };
