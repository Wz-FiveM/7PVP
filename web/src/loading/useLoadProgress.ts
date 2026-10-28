import { useEffect, useState } from 'react';

/**
 * Progression envoyée par FiveM à l'écran de chargement (window.postMessage) :
 *   loadProgress          { loadFraction }   avancement global (0 à 1)
 *   startInitFunctionOrder / initFunctionInvoking / startDataFileEntries
 *   onDataFileEntry       { name }           fichier de données en cours
 *   performMapLoadFunction                   chargement de la carte
 *   onLogLine             { message }        ligne de journal du client
 */
interface LoadMessage {
  eventName?: string;
  loadFraction?: number;
  message?: string;
}

const STEP_LABELS: Record<string, string> = {
  startInitFunctionOrder: 'Initialisation du jeu',
  initFunctionInvoking: 'Initialisation du jeu',
  startDataFileEntries: 'Chargement des fichiers',
  onDataFileEntry: 'Chargement des fichiers',
  performMapLoadFunction: 'Chargement de la carte',
  endDataFileEntries: 'Préparation du monde',
};

export interface LoadProgress {
  /** 0 à 1 */
  fraction: number;
  step: string;
  log: string;
}

/** Hors de FiveM (npm run dev), la progression est simulée. */
const isBrowser = !(window as { invokeNative?: unknown }).invokeNative;

export function useLoadProgress(): LoadProgress {
  const [progress, setProgress] = useState<LoadProgress>({ fraction: 0, step: 'Connexion au serveur', log: '' });

  useEffect(() => {
    const onMessage = (event: MessageEvent<LoadMessage>) => {
      const data = event.data;
      const eventName = data?.eventName;
      if (!eventName) return;
      setProgress((current) => ({
        fraction: eventName === 'loadProgress' && typeof data.loadFraction === 'number'
          ? Math.max(current.fraction, data.loadFraction)
          : current.fraction,
        step: STEP_LABELS[eventName] ?? current.step,
        log: eventName === 'onLogLine' && data.message ? data.message : current.log,
      }));
    };
    window.addEventListener('message', onMessage);

    let simulation: number | undefined;
    if (isBrowser) {
      simulation = window.setInterval(() => {
        setProgress((current) => {
          const fraction = current.fraction >= 1 ? 0 : Math.min(1, current.fraction + 0.012);
          const step = fraction < 0.3 ? 'Initialisation du jeu' : fraction < 0.7 ? 'Chargement des fichiers' : 'Chargement de la carte';
          return { fraction, step, log: `données ${Math.round(fraction * 412)} / 412` };
        });
      }, 120);
    }

    return () => {
      window.removeEventListener('message', onMessage);
      window.clearInterval(simulation);
    };
  }, []);

  return progress;
}
