/** Touche du menu par défaut si la config ne l'a pas encore envoyée */
export const DEFAULT_MENU_KEY = 'VERR. MAJ';

/** Échap ou Verr. Maj ferment le menu (pas pendant la saisie dans un champ). */
export function isMenuCloseKey(event: KeyboardEvent): boolean {
  if (event.key === 'Escape') return true;
  const target = event.target as HTMLElement | null;
  const typing = target?.tagName === 'INPUT' || target?.tagName === 'TEXTAREA';
  return event.key === 'CapsLock' && !event.repeat && !typing;
}
