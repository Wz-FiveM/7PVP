declare global {
  interface Window {
    invokeNative?: unknown;
    GetParentResourceName?: () => string;
  }
}

/** true quand l'interface tourne dans un navigateur classique (npm run dev) */
export const isEnvBrowser = (): boolean => !window.invokeNative;

const resourceName = window.GetParentResourceName?.() ?? '7PVP';

/** Un callback Lua qui plante ne répond jamais : on n'attend pas plus longtemps. */
const NUI_TIMEOUT = 10000;

/**
 * Appelle un callback NUI enregistré côté Lua (`RegisterNUICallback`).
 * Hors jeu, renvoie `mock` pour pouvoir développer dans le navigateur.
 * Sans réponse (délai dépassé, erreur, réponse vide) : `undefined`, jamais d'exception,
 * pour que l'interface ne reste pas bloquée (« Déploiement… », bouton désactivé...).
 */
export async function fetchNui<T>(event: string, data: unknown = {}, mock?: T): Promise<T> {
  if (isEnvBrowser()) {
    return mock as T;
  }

  const controller = new AbortController();
  const timer = window.setTimeout(() => controller.abort(), NUI_TIMEOUT);
  try {
    const response = await fetch(`https://${resourceName}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
      signal: controller.signal,
    });
    const text = await response.text();
    return (text ? JSON.parse(text) : undefined) as T;
  } catch (error) {
    console.warn(`[7PVP] callback NUI « ${event} » sans réponse`, error);
    return undefined as T;
  } finally {
    window.clearTimeout(timer);
  }
}
