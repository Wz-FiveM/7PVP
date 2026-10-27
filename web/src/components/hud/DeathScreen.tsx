import { useCountdown } from '../../hooks/useCountdown';
import { useGame } from '../../store/GameContext';

export function DeathScreen() {
  const { state } = useGame();
  const remaining = useCountdown(state.death.seconds, state.death.key);

  return (
    <div className="death">
      <div className="death__stripes" />
      <span className="mono death__tag">// SIGNAL PERDU</span>
      <h1 className="disp death__title">Éliminé</h1>
      <p className="death__text">Le contenu de ton sac est resté sur place. Ton conteneur protégé te suit.</p>
      <span className="mono death__timer">RÉAPPARITION DANS {String(remaining).padStart(2, '0')} S</span>
    </div>
  );
}
