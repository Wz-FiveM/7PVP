declare global {
  interface Window {
    invokeNative?: unknown;
    GetParentResourceName?: () => string;
  }
}

/** true quand l'interface tourne dans un navigateur classique (npm run dev) */
export const isEnvBrowser = (): boolean => !window.invokeNative;

const resourceName = window.GetParentResourceName?.() ?? '7PVP';

/**
 * Appelle un callback NUI enregistré côté Lua (`RegisterNUICallback`).
 * Hors jeu, renvoie `mock` pour pouvoir développer dans le navigateur.
 */
export async function fetchNui<T>(event: string, data: unknown = {}, mock?: T): Promise<T> {
  if (isEnvBrowser()) {
    return mock as T;
  }

  const response = await fetch(`https://${resourceName}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });
  return response.json() as Promise<T>;
}
