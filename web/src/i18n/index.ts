import { useSyncExternalStore } from 'react';

/**
 * Traductions de l'interface. Le texte français sert de clé : locales/<langue>.json (à la racine
 * de la resource, partagé avec Lua) associe chaque texte français à sa traduction, et un texte
 * absent du fichier reste en français.
 *
 *   const t = useT();                 // dans un composant : il se redessine au changement de langue
 *   t('Déployer')
 *   t('Niveau {level}', { level: 3 }) // variables entre accolades, gardées telles quelles dans les traductions
 *
 * Hors composant (constantes, fonctions appelées pendant le rendu), garder le texte français et
 * appeler `t` au moment de l'afficher. La langue est choisie côté Lua (client/modules/locale/language.lua).
 */

export interface LanguageInfo {
  id: string;
  label: string;
}

export const SOURCE_LANG = 'fr';

/** Liste par défaut (navigateur, écran de chargement) ; en jeu, celle de Config.Locale l'emporte */
let languages: LanguageInfo[] = [
  { id: 'fr', label: 'Français' },
  { id: 'en', label: 'English' },
  { id: 'es', label: 'Español' },
  { id: 'de', label: 'Deutsch' },
  { id: 'it', label: 'Italiano' },
  { id: 'pt', label: 'Português' },
];

/** Format des nombres et des dates de chaque langue */
const NUMBER_LOCALES: Record<string, string> = {
  fr: 'fr-FR',
  en: 'en-US',
  es: 'es-ES',
  de: 'de-DE',
  it: 'it-IT',
  pt: 'pt-BR',
};

type Dictionary = Record<string, string>;

// Un fichier par langue, chargé à la demande (chunk séparé dans le build)
const loaders = import.meta.glob<Dictionary>('../../../locales/*.json', { import: 'default' });

let lang = SOURCE_LANG;
let dictionary: Dictionary = {};
let version = 0;
let request = 0;
const listeners = new Set<() => void>();

const notify = () => {
  version += 1;
  listeners.forEach((listener) => listener());
};

/** Change la langue affichée (le dictionaire est chargé avant de redessiner). */
export async function setLanguage(next: string, list?: LanguageInfo[]): Promise<void> {
  if (list?.length) languages = list;
  const current = ++request;
  const loader = loaders[`../../../locales/${next}.json`];
  let loaded: Dictionary = {};
  if (next !== SOURCE_LANG && loader) {
    try {
      loaded = await loader();
    } catch (error) {
      console.warn(`[7PVP] traductions « ${next} » introuvables`, error);
    }
  }
  // Un autre changement est arrivé pendant le chargement : il l'emporte
  if (current !== request) return;
  lang = next;
  dictionary = loaded;
  document.documentElement.lang = next;
  notify();
}

/** Texte dans la langue du joueur ; `{nom}` est remplacé par `vars.nom`. */
export function t(text: string, vars?: Record<string, string | number>): string {
  const translated = dictionary[text] ?? text;
  if (!vars) return translated;
  return translated.replace(/\{(\w+)\}/g, (match, key: string) => (key in vars ? String(vars[key]) : match));
}

export const getLanguage = (): string => lang;

export const getLanguages = (): LanguageInfo[] => languages;

/** Code régional pour toLocaleString / Intl (ex : 'en-US') */
export const numberLocale = (): string => NUMBER_LOCALES[lang] ?? NUMBER_LOCALES[SOURCE_LANG];

/** Nombre formaté dans la langue du joueur (séparateur de milliers...) */
export const formatNumber = (value: number, options?: Intl.NumberFormatOptions): string =>
  value.toLocaleString(numberLocale(), options);

/** Langue du navigateur parmi celles disponibles (écran de chargement, avant le choix enregistré) */
export function browserLanguage(): string {
  const code = navigator.language?.slice(0, 2).toLowerCase();
  return languages.some((language) => language.id === code) ? code : SOURCE_LANG;
}

const subscribe = (listener: () => void) => {
  listeners.add(listener);
  return () => listeners.delete(listener);
};

const getVersion = () => version;

/** À appeler dans chaque composant qui affiche du texte : il se redessine au changement de langue. */
export function useT(): typeof t {
  useSyncExternalStore(subscribe, getVersion);
  return t;
}

/** Langue en cours (redessine au changement) */
export function useLanguage(): string {
  useSyncExternalStore(subscribe, getVersion);
  return lang;
}
