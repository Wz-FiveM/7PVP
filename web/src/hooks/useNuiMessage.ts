import { useEffect, useRef } from 'react';
import type { NuiMessage } from '../types/nui';

/** Écoute les messages envoyés par Lua (`SendNUIMessage`). */
export function useNuiMessage(handler: (message: NuiMessage) => void): void {
  const handlerRef = useRef(handler);

  useEffect(() => {
    handlerRef.current = handler;
  }, [handler]);

  useEffect(() => {
    const listener = (event: MessageEvent<NuiMessage>) => {
      if (event.data && typeof event.data.action === 'string') {
        handlerRef.current(event.data);
      }
    };
    window.addEventListener('message', listener);
    return () => window.removeEventListener('message', listener);
  }, []);
}
