/** Miroir de shared/modules/appearance.lua */

export type Sex = 'male' | 'female';
export type CreatorMode = 'create' | 'edit';
export type CameraPreset = 'face' | 'torso' | 'body';
export type Rgb = [number, number, number];

export interface OverlayValue {
  /** -1 = aucun */
  style: number;
  opacity: number;
  color: number;
}

export interface DrawableValue {
  /** -1 = aucun (accessoires uniquement) */
  drawable: number;
  texture: number;
}

export interface Appearance {
  sex: Sex;
  heritage: { mother: number; father: number; shapeMix: number; skinMix: number };
  features: number[];
  eyeColor: number;
  hair: { style: number; color: number; highlight: number };
  overlays: Record<string, OverlayValue>;
  components: Record<string, DrawableValue>;
  props: Record<string, DrawableValue>;
}

export interface DrawableLimit {
  drawables: number;
  textures: number;
}

export interface CreatorLimits {
  hair: number;
  overlays: Record<string, number>;
  components: Record<string, DrawableLimit>;
  props: Record<string, DrawableLimit>;
}

export interface SchemaEntry {
  key: string;
  label: string;
  /** 1 = couleurs de cheveux, 2 = couleurs de maquillage */
  color?: 1 | 2;
}

export interface CreatorSchema {
  mothers: number[];
  fathers: number[];
  features: string[];
  overlays: SchemaEntry[];
  components: SchemaEntry[];
  props: SchemaEntry[];
}

export interface CreatorPalettes {
  hair: Rgb[];
  makeup: Rgb[];
}

/** Message NUI `creator` */
export interface CreatorPayload {
  open: boolean;
  mode?: CreatorMode;
  appearance?: Appearance;
  limits?: CreatorLimits;
  palettes?: CreatorPalettes;
  schema?: CreatorSchema;
}

/** Réponse du callback `creatorApply` */
export interface CreatorApplyResult {
  limits?: CreatorLimits;
  /** renvoyée quand le sexe a changé (apparence par défaut du nouveau modèle) */
  appearance?: Appearance;
}
