import { useEffect, useState } from 'react';
import { useGame } from '../../store/GameContext';

const TICK = 250;

/** Statut « en combat » en haut au centre : se déconnecter maintenant compte comme une mort. */
export function CombatTag() {
  const { state } = useGame();
  const [now, setNow] = useState(Date.now);
  const active = state.combatUntil > now;

  useEffect(() => {
    if (state.combatUntil <= Date.now()) return undefined;
    setNow(Date.now());
    const timer = window.setInterval(() => setNow(Date.now()), TICK);
    return () => window.clearInterval(timer);
  }, [state.combatUntil]);

  if (!active) return null;
  const seconds = Math.ceil((state.combatUntil - now) / 1000);

  return (
    <div className="combat-tag">
      <div className="stripes" />
      <div className="combat-tag__body">
        <span className="disp combat-tag__title">En combat</span>
        <span className="mono combat-tag__time">{seconds} s</span>
      </div>
      <span className="label combat-tag__hint">Quitter maintenant = mort</span>
    </div>
  );
}
