/**
 * Mise à l'échelle de l'interface selon la résolution.
 *
 * Toutes les tailles CSS sont en rem : 1rem = 16px en 1920x1080. La taille de base
 * suit le plus petit des deux rapports (largeur / hauteur), pour que rien ne déborde
 * en ultrawide : 2560x1440 → x1.33, 3440x1440 → x1.33, 3840x2160 → x2.
 * En dessous du 1080p, l'échelle ne descend pas sous x0.85 pour garder le texte lisible.
 */
export const BASE_WIDTH = 1920;
export const BASE_HEIGHT = 1080;
export const BASE_FONT_SIZE = 16;

const MIN_SCALE = 0.85;
const MAX_SCALE = 3;

export function computeUiScale(width = window.innerWidth, height = window.innerHeight): number {
  const scale = Math.min(width / BASE_WIDTH, height / BASE_HEIGHT);
  return Math.min(MAX_SCALE, Math.max(MIN_SCALE, scale));
}

/** Échelle actuellement appliquée (utile pour convertir des déplacements de souris). */
export function currentUiScale(): number {
  return parseFloat(document.documentElement.style.getPropertyValue('--ui-scale')) || 1;
}

export function applyUiScale(): void {
  const scale = computeUiScale();
  const root = document.documentElement;
  root.style.fontSize = `${BASE_FONT_SIZE * scale}px`;
  root.style.setProperty('--ui-scale', String(scale));
}

/** Applique l'échelle maintenant et à chaque redimensionnement de la fenêtre. */
export function watchUiScale(): void {
  applyUiScale();
  window.addEventListener('resize', applyUiScale);
}

/** Convertit une taille de maquette (px en 1080p) en rem. */
export const rem = (px: number): string => `${px / BASE_FONT_SIZE}rem`;
