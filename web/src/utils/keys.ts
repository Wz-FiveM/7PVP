/** Touche du menu par défaut si la config ne l'a pas encore envoyée */
export const DEFAULT_MENU_KEY = 'TAB';

/** Échap ou Tab ferment le menu (pas pendant la saisie dans un champ). */
export function isMenuCloseKey(event: KeyboardEvent): boolean {
  if (event.key === 'Escape') return true;
  const target = event.target as HTMLElement | null;
  const typing = target?.tagName === 'INPUT' || target?.tagName === 'TEXTAREA';
  if (event.key !== 'Tab' || event.repeat || typing) return false;
  // Tab déplacerait sinon le focus d'un bouton à l'autre
  event.preventDefault();
  return true;
}
