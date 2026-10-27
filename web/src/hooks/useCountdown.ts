import { useEffect, useState } from 'react';

/** Compte à rebours en secondes, relancé à chaque changement de `key`. */
export function useCountdown(seconds: number, key: unknown): number {
  const [remaining, setRemaining] = useState(seconds);

  useEffect(() => {
    setRemaining(seconds);
    const interval = window.setInterval(() => {
      setRemaining((value) => Math.max(0, value - 1));
    }, 1000);
    return () => window.clearInterval(interval);
  }, [seconds, key]);

  return remaining;
}
